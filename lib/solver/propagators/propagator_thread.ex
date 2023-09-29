defmodule CPSolver.Propagator.Thread do
  alias CPSolver.Variable
  alias CPSolver.Common
  alias CPSolver.Utils
  alias CPSolver.Propagator.Variable, as: PropagatorVariable

  require Logger

  @behaviour GenServer

  @domain_changes Common.domain_changes()

  ## Create a propagator thread; 'propagator' is a tuple {propagator_mod, args} where propagator_mod
  ## is an implementation of CPSolver.Propagator
  ##
  ## Propagator thread is a process that handles life cycle of a propagator.
  ## TODO: details to follow.
  def create_thread(space, propagator, opts \\ [id: make_ref()])

  def create_thread(
        space,
        {propagator_mod, propagator_args} = _propagator,
        opts
      )
      when is_atom(propagator_mod) do
    {:ok, _thread} =
      GenServer.start_link(__MODULE__, [space, propagator_mod, propagator_args, opts])
  end

  def create_thread(space, propagator, opts) do
    [propagator_mod | args] = Tuple.to_list(propagator)
    create_thread(space, {propagator_mod, args}, opts)
  end

  def dispose(%{thread: pid} = _thread) do
    dispose(pid)
  end

  def dispose(pid) when is_pid(pid) do
    (Process.alive?(pid) && GenServer.stop(pid)) || :not_found
  end

  ## Subscribe propagator thread to variables' events
  defp subscribe_to_variables(thread, variables) do
    Enum.each(variables, fn var -> subscribe_to_var(thread, var) end)
  end

  defp subscribe_to_var(thread, variable) do
    Variable.subscribe(thread, variable)
  end

  defp unsubscribe_from_var(thread, variable) do
    Variable.unsubscribe(thread, variable)
  end

  ## GenServer callbacks
  @impl true
  def init([space, propagator_mod, args, opts]) do
    store = Keyword.get(opts, :store)
    store_impl = Keyword.get(opts, :store_impl, CPSolver.ConstraintStore.default_store())
    PropagatorVariable.set_store_impl(store_impl)

    propagator_vars =
      Enum.map(propagator_mod.variables(args), fn var -> Map.put(var, :store, store) end)

    subscribe_to_variables(self(), propagator_vars)
    propagator_id = Keyword.get(opts, :id, make_ref())
    Utils.subscribe(space, {:propagator, propagator_id})

    {:ok,
     %{
       id: propagator_id,
       space: space,
       store: store,
       store_impl: store_impl,
       stable: false,
       propagator_impl: propagator_mod,
       propagate_on: Keyword.get(opts, :propagate_on, propagator_mod.events()),
       args:
         Enum.map(args, fn
           %Variable{} = arg ->
             Map.put(arg, :store, store)

           const ->
             const
         end),
       unfixed_variables:
         Enum.reduce(propagator_vars, MapSet.new(), fn var, acc ->
           (Variable.fixed?(var) && acc) || MapSet.put(acc, var.id)
         end),
       propagator_opts: opts
     }, {:continue, :filter}}
  end

  @impl true
  def handle_continue(:filter, data) do
    filter(data)
  end

  @impl true

  def handle_info({:fail, var}, data) do
    handle_failure(var, data)
  end

  def handle_info({:fixed, var}, data) do
    new_data = update_unfixed(data, var)

    unsubscribe_from_var(self(), var)

    if entailed?(new_data) do
      handle_entailed(new_data)
    else
      filter(new_data)
    end
  end

  def handle_info({domain_change, _var}, data) when domain_change in @domain_changes do
    if domain_change in data.propagate_on do
      filter(data)
    else
      noop(data)
    end
  end

  ### end of GenServer callbacks
  defp noop(data) do
    {:noreply, data}
  end

  defp filter(%{propagator_impl: mod, args: args} = data) do
    Logger.debug("#{inspect(data.id)}: Propagation triggered")
    PropagatorVariable.reset_variable_ops()

    case mod.filter(args) do
      :stable ->
        handle_stable(data)

      _res ->
        ## If propagator doesn't explicitly return 'stable',
        ## we look into the map of variable operations created by PropagatorVariable wrapper
        handle_variable_ops(data)
    end
  end

  defp handle_variable_ops(data) do
    case PropagatorVariable.get_variable_ops() do
      {:fail, var} ->
        handle_failure(var, data)

      ops when is_map(ops) ->
        {updated_data, changed?} = Enum.reduce(ops, {data, false}, &process_var_ops/2)

        cond do
          entailed?(updated_data) -> handle_entailed(updated_data)
          changed? -> handle_running(updated_data)
          true -> handle_stable(updated_data)
        end
    end
  end

  defp process_var_ops({var, :fixed}, {data, _} = _acc) do
    {update_unfixed(data, var), true}
  end

  defp process_var_ops({_var, :no_change}, acc) do
    acc
  end

  defp process_var_ops({_var, domain_change}, {data, current_status} = _acc)
       when domain_change in @domain_changes do
    {data, current_status || domain_change in data.propagate_on}
  end

  defp handle_stable(data) do
    Logger.debug("#{inspect(data.id)} Propagator is stable")
    !data.stable && publish(data, :stable)
    {:noreply, %{data | stable: true}}
  end

  defp handle_running(data) do
    publish(data, :running)
    {:noreply, %{data | stable: false}}
  end

  defp handle_entailed(data) do
    Logger.debug("#{inspect(data.id)} Propagator is entailed (on filtering)")
    publish(data, :entailed)
    stop(data)
  end

  def handle_failure(var, data) do
    Logger.debug("#{inspect(data.id)} Propagator: Failure for #{inspect(var)}")
    publish(data, :failed)
    stop(data)
  end

  defp entailed?(%{unfixed_variables: vars} = _data) do
    entailed?(vars)
  end

  defp entailed?(vars) when is_map(vars) do
    MapSet.size(vars) == 0
  end

  defp update_unfixed(%{unfixed_variables: unfixed} = data, var) do
    %{data | unfixed_variables: MapSet.delete(unfixed, var)}
  end

  defp publish(%{id: id, space: space} = _data, message) do
    send(space, {message, id})
  end

  defp stop(data) do
    Enum.each(data.unfixed_variables, fn var -> Variable.unsubscribe(self(), var) end)
    {:stop, :normal, data}
  end
end
