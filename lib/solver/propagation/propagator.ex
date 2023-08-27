defmodule CPSolver.Propagator do
  alias CPSolver.Store.Registry, as: Store
  alias CPSolver.Variable
  alias CPSolver.Common
  alias CPSolver.Utils

  require Logger

  @callback filter(variables :: list()) :: map() | :stable | :failure
  @callback variables(args :: list()) :: list()

  @domain_changes Common.domain_changes()

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
    {:ok, _thread} =
      GenServer.start_link(__MODULE__, [space, propagator_mod, propagator_args, opts])
  end

  def create_thread(space, propagator, opts) do
    [propagator_mod | args] = Tuple.to_list(propagator)
    create_thread(space, {propagator_mod, args}, opts)
  end

  ## Subscribe propagator thread to variables' events
  defp subscribe_to_variables(thread, variables) do
    Enum.each(variables, fn var -> subscribe_to_var(thread, var) end)
  end

  defp subscribe_to_var(thread, variable) do
    Utils.subscribe(thread, variable.id)
  end

  defp unsubscribe_from_var(thread, var_id) do
    Utils.unsubscribe(thread, var_id)
  end

  ## GenServer callbacks
  @impl true
  def init([space, propagator_mod, args, opts]) do
    bound_vars = Variable.bind_variables(space, propagator_mod.variables(args))
    subscribe_to_variables(self(), bound_vars)
    propagator_id = Keyword.get(opts, :id, make_ref())
    Utils.subscribe(space, propagator_id)

    {:ok,
     %{
       id: propagator_id,
       space: space,
       propagator_impl: propagator_mod,
       args: args,
       unfixed_variables:
         Enum.reduce(bound_vars, Map.new(), fn var, acc ->
           (Store.get(space, var, :fixed?) && acc) || Map.put(acc, var.id, %{stable: false})
         end),
       propagator_opts: opts,
       filter_fun: fn -> propagator_mod.filter(args) end,
       on_startup: true
     }
     |> tap(fn data ->
       filter(data)
     end)}
  end

  @impl true

  def handle_info({:fail, var}, data) do
    Logger.debug("#{inspect(data.id)} Propagator: Failure for #{inspect(var)}")
    publish(data, :failed)
    {:stop, :normal, data}
  end

  def handle_info({:no_change, var}, data) do
    Logger.debug("#{inspect(data.id)} Propagator: no change for #{inspect(var)}")

    if data.on_startup && entailed?(data) do
      Logger.debug("#{inspect(data.id)} Propagator is entailed (on a startup)")
      publish(data, :entailed)
      {:stop, :normal, data}
    else
      {:noreply,
       data
       |> Map.put(:on_startup, false)
       |> update_stable(var, true)
       |> tap(fn new_data ->
         if stable?(new_data) do
           handle_stable(new_data)
         end
       end)}
    end
  end

  def handle_info({:fixed, var}, data) do
    new_data = update_unfixed(data, var)

    if entailed?(new_data) do
      Logger.debug("#{inspect(data.id)} Propagator is entailed (on filtering)")
      publish(data, :entailed)
      {:stop, :normal, new_data}
    else
      filter(new_data)
      {:noreply, new_data}
    end
  end

  def handle_info({domain_change, var}, data) when domain_change in @domain_changes do
    Logger.debug("#{inspect(data.id)} Propagator: #{inspect(domain_change)} for #{inspect(var)}")
    filter(data)
    {:noreply, update_stable(data, var, false)}
  end

  ### end of GenServer callbacks

  defp filter(%{filter_fun: filter_fun} = data) do
    case filter_fun.() do
      :stable ->
        handle_stable(data)

      _res ->
        handle_running(data)
    end
  end

  defp entailed?(%{unfixed_variables: vars} = _data) do
    entailed?(vars)
  end

  defp entailed?(vars) when is_map(vars) do
    map_size(vars) == 0
  end

  defp update_unfixed(%{unfixed_variables: unfixed} = data, var) do
    unsubscribe_from_var(self(), var)
    %{data | unfixed_variables: Map.delete(unfixed, var)}
  end

  defp update_stable(%{unfixed_variables: unfixed} = data, var, stable?) do
    %{
      data
      | unfixed_variables:
          Map.update!(unfixed, var, fn content -> Map.put(content, :stable, stable?) end)
    }
  end

  defp stable?(%{unfixed_variables: unfixed} = _data) do
    Enum.all?(unfixed, fn {_k, v} -> v.stable end)
  end

  defp handle_stable(data) do
    Logger.debug("#{inspect(data.id)} Propagator #{inspect(self())} is stable")
    publish(data, :stable)
  end

  defp handle_running(data) do
    publish(data, :running)
  end

  defp publish(data, message) do
    Utils.publish(data.id, {message, data.id})
  end
end
