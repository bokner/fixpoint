defmodule CPSolver.Search.VariableSelector.MostCompleted do
  use CPSolver.Search.VariableSelector
  alias CPSolver.Propagator.ConstraintGraph

  @impl true
  def select(_variables, space_data, _opts) do
    most_completed_propagators_selection(space_data[:constraint_graph])
  end

  ## Choose variables connected to "most completed" propagators.
  ## 1) Choose propagators with smallest number of still unfixed variables
  ## (this corresponds to propagators with smallest degree in constraint graph).
  ## 2) Choose variables most constrained by the propagators above.
  def most_completed_propagators_selection(constraint_graph) do
    ## Make p => (unfixed variables) map
    constraint_graph
    |> Graph.edges()
    |> Enum.group_by(
      fn edge -> edge.v2 end,
      fn edge -> edge.v1 end
    )
    ## Pick out the propagators with minimal number of unfixed variables.
    ## Build the list of variable ids constrained by those propagators.
    |> Enum.reduce(
      {[], nil},
      fn {_propagator_id, var_ids}, {var_ids_acc, current_min} = acc ->
        var_count = length(var_ids)

        cond do
          is_nil(current_min) || var_count < current_min -> {var_ids, var_count}
          var_count > current_min -> acc
          var_count == current_min -> {var_ids ++ var_ids_acc, var_count}
        end
      end
    )
    |> elem(0)
    ## Choose variables with the largest counts of constraints (i.e., attached propagators)
    |> Enum.frequencies()
    |> Enum.reduce({[], nil}, fn {var_id, var_count}, {vars_acc, current_max} = acc ->
      graph_var = ConstraintGraph.get_variable(constraint_graph, var_id)

      cond do
        is_nil(current_max) || var_count > current_max -> {[graph_var], var_count}
        var_count < current_max -> acc
        var_count == current_max -> {[graph_var | vars_acc], var_count}
      end
    end)
    |> elem(0)
  end
end
