defmodule CPSolver.Search.VariableSelector.MostConstrained do
  use CPSolver.Search.VariableSelector
  alias CPSolver.Variable.Interface
  alias CPSolver.Search.Utils, as: SearchUtils
  alias CPSolver.Propagator.ConstraintGraph

  @impl true
  def select(space_data, _opts) do
    get_maximals(space_data)
  end

  defp get_maximals(%{unfixed_variables_tracker: tracker, variables: variables} = space_data) do
    max_by_fun = fn var ->
      ConstraintGraph.variable_degree(space_data[:constraint_graph], Interface.id(var))
    end

    SearchUtils.maximals(tracker, variables, max_by_fun)
  end
end
