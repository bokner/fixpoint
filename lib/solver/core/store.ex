defmodule CPSolver.ConstraintStore do
  @behaviour GenServer

  ### GenServer callbacks
  @impl true
  def init([space, variables, opts] = _args) do
    backend = Keyword.get(opts, :backend, CPSolver.Store.ETS)
    {:ok, %{space: space, variables: tell_variables(variables, space, backend), backend: backend}}
  end

  @impl true
  def handle_info({:filter, propagator, remove_op, variable, value}, state) when remove_op in [:remove, :removeAbove, :removeBelow, :removeAllBut, :fix] do
    process_remove(propagator, remove_op, variable, value, state)
    {:noreply, state}
  end

  def handle_info({:subscribe, propagator, variables}, %{space: space} = state) do
    Enum.each(variables, fn var -> :ebus.sub(propagator, variable_topic(var, space)) end)
    {:noreply, state}
  end

  #################

  ## Write initial domains
  defp tell_variables(variables, space, backend) do
  end

  defp process_remove(propagator, remove_op, variable, value, %{space: space} = state)
       when remove_op in [:remove, :removeAbove, :removeBelow, :removeAllBut, :fix] do
        case apply(state.backend, remove_op, [variable, value]) do
          :ok -> continue_propagation(variable, space)
          :not_changed -> deactivate_propagator(propagator, space)
          :fixed -> maybe_entail_propagator(propagator, space)
          :failure -> fail_propagator(propagator, space)

        end
  end

  ### API
  def create(space, variables, opts \\ []) do
    {:ok, _store} = GenServer.start_link(__MODULE__, [space, variables, opts])
  end

  def get_variable(variable, store) do
  end

  defp subscribe_to_variable(propagator, store, variables) do
    send(store, {:subscribe, propagator, variables})
  end

  defp variable_topic(variable, space) do
    {space, variable}
  end

  ## Filtering-related effects
  defp continue_propagation(variable, space) do
    :ebus.pub(variable_topic(variable, space), :domain_change)
  end

  defp deactivate_propagator(propagator, space) do
    send(space, {:deactivate, propagator})
  end

  defp maybe_entail_propagator(propagator, space) do
    send(space, {:maybe_entail, propagator})
  end

  defp fail_propagator(propagator, space) do
    send(space, {:fail, propagator})
  end
end
