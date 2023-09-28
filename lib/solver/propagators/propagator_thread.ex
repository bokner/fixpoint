defmodule CPSolver.Propagator.Thread do
  alias CPSolver.Variable
  alias CPSolver.Common
  alias CPSolver.Utils
  alias CPSolver.Propagator
  alias CPSolver.Propagator.Variable, as: PropagatorVariable

  require Logger

  @behaviour :gen_statem

  @domain_changes Common.domain_changes()

  ## Create a propagator thread; 'propagator' is a tuple {propagator_mod, args} where propagator_mod
  ## is an implementation of CPSolver.Propagator
  ##
  ## Propagator thread is a process that handles life cycle of a propagator.
  ## TODO: details to follow.
  def create_thread(space, propagator, opts \\ [id: make_ref()], gen_statem_opts \\ [])

  def create_thread(
        space,
        propagator,
        opts,
        gen_statem_opts
      ) do
    {propagator_mod, propagator_args} = Propagator.normalize(propagator)

    {:ok, _thread} =
      :gen_statem.start_link(
        __MODULE__,
        [space, propagator_mod, propagator_args, opts],
        gen_statem_opts
      )
  end

  def dispose(%{thread: pid} = _thread) do
    dispose(pid)
  end

  def dispose(pid) when is_pid(pid) do
    (Process.alive?(pid) && :gen_statem.stop(pid)) || :not_found
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

  ## :gen_statem callbacks

  @impl true
  def callback_mode() do
    [:state_functions, :state_enter]
  end

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

    {:ok, :running,
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
     }, [{:next_event, :internal, :filter}]}
  end

  def running(:enter, _prev_state, _data) do
    :keep_state_and_data
  end

  def running(:internal, :filter, data) do
    filter(data)
  end

  def running(_, _, data) do
    filter(data)
  end

  def entailed(:enter, _prev_state, data) do
    handle_entailed(data)
  end

  def failed(:enter, _prev_state, data) do
    handle_failure(data, nil)
  end

  def stable(:enter, _prev_state, data) do
    handle_stable(data)
  end

  def stable(:info, {:fail, var}, data) do
    handle_failure(data, var)
  end

  def stable(:info, {:fixed, var}, data) do
    new_data = update_unfixed(data, var)
    unsubscribe_from_var(self(), var)
    {:next_state, :running, new_data}
  end

  def stable(:info, {domain_change, _var}, data) when domain_change in @domain_changes do
    if domain_change in data.propagate_on do
      {:next_state, :running, data}
    else
      :keep_state_and_data
    end
  end

  defp filter(%{propagator_impl: mod, args: args} = data) do
    Logger.debug("#{inspect(data.id)}: Propagation triggered")

    ## Let the space know we are running
    publish(data, :running)
    PropagatorVariable.reset_variable_ops()

    case mod.filter(args) do
      :stable ->
        {:next_state, :stable, data}

      _res ->
        ## If propagator doesn't explicitly return 'stable',
        ## we look into the map of variable operations created by PropagatorVariable wrapper
        handle_variable_ops(data)
    end
  end

  defp handle_variable_ops(data) do
    case PropagatorVariable.get_variable_ops() do
      {:fail, _var} ->
        {:next_state, :failed, data}

      ops when is_map(ops) ->
        {updated_data, changed?} = Enum.reduce(ops, {data, false}, &process_var_ops/2)

        cond do
          entailed?(updated_data) -> {:next_state, :entailed, updated_data}
          changed? -> {:next_state, :stable, updated_data}
          true -> {:next_state, :stable, updated_data}
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
    {:next_state, :stable, %{data | stable: true}}
  end

  defp handle_entailed(data) do
    Logger.debug("#{inspect(data.id)} Propagator is entailed (on filtering)")
    publish(data, :entailed)
    stop(data)
  end

  def handle_failure(data, var) do
    var && Logger.debug("Failure for variable #{inspect(var)}")
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

  defp publish(data, message) do
    Utils.publish({:propagator, data.id}, {message, data.id})
  end

  defp stop(data) do
    Enum.each(data.unfixed_variables, fn var -> Variable.unsubscribe(self(), var) end)
    Utils.unsubscribe(data.space, {:propagator, data.id})
    {:stop, :normal, data}
  end
end
