defmodule CPSolver.Search.VariableSelector.MostConstrained do
  alias CPSolver.Variable.Interface
  alias CPSolver.Propagator.ConstraintGraph
  alias CPSolver.Search.VariableSelector.FirstFail

  def select_variable(variables, space_data, break_even_fun \\ &FirstFail.select_variable/1) do
    ## Pick out all variables with maximal degrees
    get_maximals(variables, space_data)
    |> break_even_fun.()
  end

  def candidates(variables, space_data) do
    get_maximals(variables, space_data)
  end

  defp get_maximals(variables, space_data) do
    graph = space_data[:constraint_graph]
    List.foldr(variables, {[], -1}, fn var, {vars, current_max} = acc ->
      var_id = Interface.id(var)

      deg = ConstraintGraph.variable_degree(graph, var_id)
      cond do
        deg < current_max -> acc
        deg > current_max -> {[var], deg}
        deg == current_max -> {[var | vars], deg}
      end
    end)
    |> elem(0)
  end

end
