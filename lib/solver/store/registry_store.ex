defmodule CPSolver.Store.Registry do
  alias CPSolver.ConstraintStore, as: Store
  alias CPSolver.Variable.Agent, as: VariableAgent
  alias CPSolver.Utils

  require Logger

  use Store

  @impl true
  def create(variables, _opts \\ []) do
    store = self()

    Enum.each(
      variables,
      fn var ->
        {:ok, _pid} = VariableAgent.create(var)
      end
    )

    {:ok, store}
  end

  @impl true
  def dispose(_store, variables) do
    Enum.each(variables, &VariableAgent.dispose/1)
  end

  @impl true
  def get(_store, var, operation, args \\ []) do
    VariableAgent.operation(var, operation, args)
  end

  @impl true
  def domain(_store, var) do
    VariableAgent.operation(var, :domain)
  end

  @impl true
  def update_domain(_store, var, operation, args \\ []) do
    VariableAgent.operation(var, operation, args)
  end

  @impl true
  def on_change(_store, var, domain_change) do
    publish(var, domain_change)
    |> tap(fn _ ->
      Logger.debug("Domain change (#{domain_change}) for #{inspect(var.id)}")
    end)
  end

  @impl true
  def on_fail(_store, var) do
    Logger.debug("Failure for variable #{inspect(var.id)}")
    ## TODO: notify space (and maybe don't notify propagators)
    publish(var, :fail)
  end

  @impl true
  def on_no_change(_store, _var) do
    :ok
  end

  @impl true
  def subscribe(_store, subscriptions) do
    Enum.each(subscriptions, fn %{pid: pid, variable: var} -> subscribe_to_variable(pid, var) end)
  end

  defp publish(variable, event) do
    Utils.publish(variable_topic(variable), {event, variable.id})
  end

  defp subscribe_to_variable(pid, variable) do
    Utils.subscribe(pid, variable_topic(variable))
  end

  defp variable_topic(var) when is_map(var) do
    variable_topic(var.id)
  end

  defp variable_topic(var) when is_reference(var) do
    {:variable, var}
  end

  def variable_proc_id(variable) do
    {:global, variable.id}
  end

  @impl true
  @spec get_variables(any()) :: [reference()]
  def get_variables(space) do
    Registry.select(CPSolver.Store.Registry, [
      {{:"$1", :_, :"$3"}, [{:==, :"$3", space}], [:"$1"]}
    ])
  end
end
