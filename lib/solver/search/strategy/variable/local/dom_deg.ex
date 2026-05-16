defmodule CPSolver.Search.VariableSelector.DomDeg do
  use CPSolver.Search.VariableSelector
  alias CPSolver.Variable.Interface
  alias CPSolver.Propagator.ConstraintGraph
  alias CPSolver.Search.Utils, as: SearchUtils

  @impl true
  def select(space_data, _opts) do
    smallest_ratio(space_data)
  end

  ## Smallest ratio of dom(x)/deg(x)
  defp smallest_ratio(space_data) do
    graph = space_data[:constraint_graph]

    min_by_fun = fn var ->
      case ConstraintGraph.variable_degree(graph, Interface.id(var)) do
        deg when deg > 0 -> Interface.size(var) / deg
        _ -> nil
      end
    end

    SearchUtils.minimals(space_data, min_by_fun)
  end
end
