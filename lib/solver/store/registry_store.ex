defmodule CPSolver.Store.Registry do
  alias CPSolver.ConstraintStore, as: Store
  alias CPSolver.Variable.Agent, as: VariableAgent

  require Logger

  @behaviour Store

  @impl true
  def create(variables, _opts \\ []) do
    space = self()

    {:ok,
     Enum.map(
       variables,
       fn var ->
         {:ok, _pid} = VariableAgent.create(var)

         %{}
         |> Map.put(:id, var.id)
         |> Map.put(:space, space)
       end
     ), space}
  end

  @impl true
  def dispose(_store, variable) do
    VariableAgent.dispose(variable)
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
  def update(_store, var, operation, args \\ []) do
    VariableAgent.operation(var, operation, args)
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
