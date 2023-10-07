defmodule CPSolver.Propagator.Thread do
  alias CPSolver.Variable
  alias CPSolver.Common
  alias CPSolver.Propagator

  require Logger

  @behaviour GenServer

  @domain_changes Common.domain_changes()

  @doc """
  Create a propagator thread; 'propagator' is a tuple {propagator_mod, args} where propagator_mod
   is an implementation of CPSolver.Propagator

  Propagator thread is a process that handles life cycle of a propagator.
  TODO: details to follow.
  """
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

  def propagate(thread_pid) when is_pid(thread_pid) do
    GenServer.cast(thread_pid, :filter)
  end

  def dispose(%{thread: pid} = _thread) do
    dispose(pid)
  end

  def dispose(pid) when is_pid(pid) do
    (Process.alive?(pid) && GenServer.stop(pid)) || :not_found
  end

  ## Subscribe propagator thread to variables' events
  defp subscribe_to_variables(store, store_impl, thread, variables, events) do
    variables
    |> Enum.map(fn var -> %{pid: thread, variable: var, events: events} end)
    |> then(fn subscriptions -> store_impl.subscribe(store, subscriptions) end)
  end

  ## GenServer callbacks
  @impl true
  def init([space, propagator_mod, args, opts]) do
    store = Keyword.get(opts, :store)
    store_impl = Keyword.get(opts, :store_impl, CPSolver.ConstraintStore.default_store())

    propagator_args =
      Enum.map(args, fn
        %Variable{} = arg ->
          arg
          |> Map.put(:store, store)
          |> Map.put(:store_impl, store_impl)

        const ->
          const
      end)

    propagator_vars = propagator_mod.variables(propagator_args)
    propagation_events = Keyword.get(opts, :propagate_on, propagator_mod.events())
    subscribe_to_variables(store, store_impl, self(), propagator_vars, propagation_events)
    propagator_id = Keyword.get(opts, :id, make_ref())

    {:ok,
     %{
       id: propagator_id,
       space: space,
       store: store,
       store_impl: store_impl,
       stable: false,
       propagator_impl: propagator_mod,
       propagate_on: propagation_events,
       args: propagator_args,
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
  def handle_cast(:filter, data) do
    filter(data)
  end

  @impl true

  def handle_info({:fail, var}, data) do
    handle_failure(var, data)
  end

  def handle_info({:fixed, _var} = fix, data) do
    data
    |> update_unfixed(fix)
    |> filter()
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

    case Propagator.filter(mod, args) do
      {:fail, var} ->
        handle_failure(var, data)

      :stable ->
        handle_stable(data)

      {:changed, variable_changes} ->
        data
        |> update_unfixed(variable_changes)
        |> filter()
    end
  end

  defp handle_stable(data) do
    if entailed?(data) do
      handle_entailed(data)
    else
      Logger.debug("#{inspect(data.id)} Propagator is stable")
      publish(data, :stable)
      {:noreply, data}
    end
  end

  defp handle_entailed(data) do
    Logger.debug("#{inspect(data.id)} Propagator is entailed (on filtering)")
    publish(data, :entailed)
    stop(data)
  end

  def handle_failure(var, data) do
    Logger.debug("#{inspect(data.id)} Propagator: Failure for variable #{inspect(var)}")
    publish(data, :failed)
    stop(data)
  end

  defp entailed?(%{unfixed_variables: vars} = _data) do
    entailed?(vars)
  end

  defp entailed?(vars) when is_map(vars) do
    MapSet.size(vars) == 0
  end

  defp update_unfixed(data, {_change_type, _var} = change) do
    update_unfixed(data, [change])
  end

  defp update_unfixed(%{unfixed_variables: unfixed} = data, variable_changes)
       when is_list(variable_changes) do
    ## variable_changes is a list of {:change_type, variable_id}
    fixed_vars =
      Enum.flat_map(variable_changes, fn
        {:fixed, var} -> [var]
        _ -> []
      end)

    new_unfixed = MapSet.reject(unfixed, fn v -> v in fixed_vars end)
    %{data | unfixed_variables: new_unfixed}
  end

  defp publish(%{id: id, space: space} = _data, message) do
    send(space, {message, id})
  end

  defp stop(data) do
    {:stop, :normal, data}
  end
end
