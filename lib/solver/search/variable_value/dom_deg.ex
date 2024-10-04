defmodule CPSolver.Search.VariableSelector.DomDeg do
  alias CPSolver.Variable.Interface
  alias CPSolver.Propagator.ConstraintGraph

  def candidates(variables, space_data) do
    smallest_ratio(variables, space_data)
  end
  ## Smallest ratio of dom(x)/deg(x)
  defp smallest_ratio(variables, space_data) do
    graph = space_data[:constraint_graph]
    List.foldr(variables, {[], nil}, fn var, {vars, current_min} = acc ->
      case ConstraintGraph.variable_degree(graph, Interface.id(var)) do
        deg when deg > 0 ->
          ratio = Interface.size(var) / deg

          cond do
            is_nil(current_min) || ratio < current_min -> {[var], ratio}
            ratio > current_min -> acc
            ratio == current_min -> {[var | vars], ratio}
          end

        deg when (is_nil(deg) or deg == 0) ->
          acc
      end
    end)
    |> elem(0)
  end

  def select_variable(variables, space_data, break_even_fun \\ &List.first/1) do
    smallest_ratio(variables, space_data)
    |> break_even_fun.()
  end

end
