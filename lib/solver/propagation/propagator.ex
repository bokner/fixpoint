defmodule CPSolver.Propagator do
  @callback filter(variables :: list()) :: map() | :stable | :failure

  @behaviour GenServer

  ## Create a propagator thread; :propagator_mod is an module
  ## that implements CPSolver.Propagator
  ##
  def create_thread(space, propagator_mod, opts) when is_atom(propagator_mod) do
    {:ok, thread} = GenServer.start_link(__MODULE__, [space, propagator_mod, opts])
    subscribe_to_variables(propagator_mod, thread)
  end

  ## Subscribe to variables' events
  defp subscribe_to_variables(propagator, thread) do
    Enum.each(propagator.variables(), fn var -> subscribe(thread, var) end)
  end

  defp subscribe(thread, var) do
    :ebus.sub(thread, variable_topic(var))
  end

  defp variable_topic(variable) do
    variable
  end

  ## GenServer callbacks
  @impl true
  def init([space, propagator, opts]) do
    {:ok, %{space: space, propagator: propagator, propagator_opts: opts}}
  end

  @impl true
  def handle_info(:domain_change, %{space: space, propagator: propagator} = state) do
    changed_variables = propagator.filter()
    publish_changes(changed_variables, space)
    {:noreply, state}
  end

  ### end of GenServer callbacks

  defp publish_changes([], space) do
    send(space, {:stable, self()})
  end

  defp publish_changes(changed_variables, _space) do
    changed_variables
    |> get_affected_propagators()
    |> publish_domain_change()
  end

  defp get_affected_propagators(changed_variables) do
    changed_variables
    |> Enum.reduce(MapSet.new(), fn var, acc ->
      MapSet.union(MapSet.new(:ebus.subscribers(var)), acc)
    end)
    |> MapSet.delete(self())
  end

  defp publish_domain_change(propagator_threads) do
    Enum.each(propagator_threads, fn pid -> send(pid, :domain_change) end)
  end
end
