defmodule CPSolver.Search.VariableSelector.MostConstrained do
  use CPSolver.Search.VariableSelector
  alias CPSolver.Variable.Interface
  alias CPSolver.Utils
  alias CPSolver.Propagator.ConstraintGraph

  @impl true
  def select(variables, space_data, _opts) do
    get_maximals(variables, space_data)
  end

  defp get_maximals(variables, space_data) do
    max_by_fun = fn var ->
      ConstraintGraph.variable_degree(space_data[:constraint_graph], Interface.id(var))
    end

    Utils.maximals(variables, max_by_fun)
  end
end
