defmodule CPSolver.Search.VariableSelector.DomDeg do
  alias CPSolver.Variable.Interface
  alias CPSolver.Propagator.ConstraintGraph
  alias CPSolver.Utils

  def select(variables, space_data) do
    smallest_ratio(variables, space_data)
  end

  ## Smallest ratio of dom(x)/deg(x)
  defp smallest_ratio(variables, space_data) do
    graph = space_data[:constraint_graph]
    min_by_fun = fn var ->
      case ConstraintGraph.variable_degree(graph, Interface.id(var)) do
        deg when deg > 0 -> Interface.size(var) / deg
        _ -> nil
      end
    end
    Utils.minimals(variables, min_by_fun)
  end

end
