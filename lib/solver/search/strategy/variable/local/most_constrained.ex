defmodule CPSolver.Search.VariableSelector.MostConstrained do
  use CPSolver.Search.VariableSelector
  alias CPSolver.Variable.Interface
  alias CPSolver.Utils
  alias CPSolver.Propagator.ConstraintGraph

  def select(variables, space_data) do
    get_maximals(variables, space_data)
  end

  defp get_maximals(variables, space_data) do
    max_by_fun = fn var ->
      ConstraintGraph.variable_degree(space_data[:constraint_graph], Interface.id(var))
    end

    Utils.maximals(variables, max_by_fun)
  end
end
