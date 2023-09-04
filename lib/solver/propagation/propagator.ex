defmodule CPSolver.Propagator do
  alias CPSolver.Variable
  alias CPSolver.Common
  alias CPSolver.Utils

  require Logger

  @callback filter(variables :: list()) :: map() | :stable | :failure
  @callback variables(args :: list()) :: list()

  @domain_changes Common.domain_changes()
  @stable_flag :stable_flag
  defmacro __using__(_) do
    quote do
      @behaviour CPSolver.Propagator
      def variables(args) do
        args
      end

      defoverridable variables: 1
    end
  end

  @behaviour GenServer

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
    {:ok, _thread} = GenServer.start(__MODULE__, [space, propagator_mod, propagator_args, opts])
  end

  def create_thread(space, propagator, opts) do
    [propagator_mod | args] = Tuple.to_list(propagator)
    create_thread(space, {propagator_mod, args}, opts)
  end

  def dispose(%{thread: pid} = _thread) do
    (Process.alive?(pid) && GenServer.stop(pid)) || :not_found
  end

  ## Subscribe propagator thread to variables' events
  defp subscribe_to_variables(thread, variables) do
    Enum.each(variables, fn var -> subscribe_to_var(thread, var) end)
  end

  defp subscribe_to_var(thread, variable) do
    Utils.subscribe(thread, {:variable, variable.id})
  end

  defp unsubscribe_from_var(thread, var_id) do
    Utils.unsubscribe(thread, {:variable, var_id})
  end

  ## GenServer callbacks
  @impl true
  def init([space, propagator_mod, args, opts]) do
    bound_vars = Variable.bind_variables(space, propagator_mod.variables(args))
    subscribe_to_variables(self(), bound_vars)
    propagator_id = Keyword.get(opts, :id, make_ref())
    Utils.subscribe(space, {:propagator, propagator_id})

    {:ok,
     %{
       id: propagator_id,
       space: space,
       propagator_impl: propagator_mod,
       args: args,
       unfixed_variables:
         Enum.reduce(bound_vars, MapSet.new(), fn var, acc ->
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
    Logger.debug("#{inspect(data.id)} Propagator: Failure for #{inspect(var)}")
    publish(data, :failed)
    {:stop, :normal, data}
  end

  def handle_info({:fixed, var}, data) do
    new_data = update_unfixed(data, var)

    if entailed?(new_data) do
      Logger.debug("#{inspect(data.id)} Propagator is entailed (on filtering)")
      publish(data, :entailed)
      {:stop, :normal, new_data}
    else
      filter(new_data)
    end
  end

  def handle_info({domain_change, var}, data) when domain_change in @domain_changes do
    Logger.debug("#{inspect(data.id)} Propagator: #{inspect(domain_change)} for #{inspect(var)}")
    filter(data)
  end

  ### end of GenServer callbacks

  defp filter(%{propagator_impl: mod, args: args} = data) do
    reset_stable_flag()

    status =
      case mod.filter(args) do
        :stable ->
          handle_stable(data)

        _res ->
          if stable_flag() do
            handle_stable(data)
          else
            handle_running(data)
          end
      end

    case status do
      :entailed -> {:stop, :normal, data}
      :stable -> {:noreply, data}
      :running -> {:noreply, data}
    end
  end

  ## 'stable' flag will be set to false if any propagator variable
  ## was changed as a result of propagator filtering.
  ## This is done by CPSolver.Propagator.Variable.
  ##
  defp reset_stable_flag() do
    Process.put(@stable_flag, true)
  end

  defp stable_flag() do
    Process.get(@stable_flag)
  end

  defp handle_stable(data) do
    if entailed?(data) do
      Logger.debug("#{inspect(data.id)} Propagator is entailed (on filtering)")
      publish(data, :entailed)
      :entailed
    else
      Logger.debug("#{inspect(data.id)} Propagator is stable")
      publish(data, :stable)
      :stable
    end
  end

  defp handle_running(data) do
    publish(data, :running)
    :running
  end

  defp entailed?(%{unfixed_variables: vars} = _data) do
    entailed?(vars)
  end

  defp entailed?(vars) when is_map(vars) do
    MapSet.size(vars) == 0
  end

  defp update_unfixed(%{unfixed_variables: unfixed} = data, var) do
    unsubscribe_from_var(self(), var)
    %{data | unfixed_variables: MapSet.delete(unfixed, var)}
  end

  defp publish(data, message) do
    Utils.publish({:propagator, data.id}, {message, data.id})
  end
end
