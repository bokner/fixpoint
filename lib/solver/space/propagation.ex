defmodule CPSolver.Space.Propagation do
  alias CPSolver.Propagator.ConstraintGraph
  alias CPSolver.Variable
  alias CPSolver.Propagator

  def propagate(map) when map_size(map) == 0 do
    :no_changes
  end

  @spec propagate(map()) :: :fail | :no_changes | {:changes, map()}
  def propagate(propagators) do
    Enum.reduce_while(propagators, %{}, fn {_ref, p}, acc ->
      case Propagator.filter(p) do
        {:changed, change} -> {:cont, Map.merge(acc, change)}
        :stable -> {:cont, acc}
        {:fail, _var} -> {:halt, :fail}
      end
    end)
    |> then(fn
      :fail ->
        :fail

      changes when map_size(changes) > 0 ->
        {:changed, changes}

      _no_changes ->
        :no_changes
    end)
  end

  def run(propagators, variables) when is_list(propagators) do
    propagators
    |> Enum.map(fn p -> {make_ref(), p} end)
    |> Map.new()
    |> run(variables)
  end

  def run(propagators, variables) when is_map(propagators) and map_size(propagators) > 0 do
    constraint_graph = ConstraintGraph.create(propagators)

    propagators
    |> run_impl(constraint_graph)
    |> finalize(constraint_graph, variables)
  end

  def run_impl(propagators, _constyraint_graph) when map_size(propagators) == 0 do
    :no_changes
  end

  def run_impl(propagators, constraint_graph) do
    case propagate(propagators) do
      :fail ->
        :fail

      :no_changes ->
        :no_changes

      {:changed, changes} ->
        wakeup(changes, constraint_graph)
        |> filter_propagators_by_ids(propagators)
        |> run_impl(constraint_graph)
    end
  end

  defp finalize(:fail, _constraint_graph, _variables) do
    :fail
  end

  ## At this point, the space is either solved or stable.
  ## Reduce constraint graph and interpret the result.
  defp finalize(:no_changes, constraint_graph, variables) do
    remove_fixed_variables(constraint_graph, variables)
    |> remove_entailed_propagators()
    |> then(fn residue -> (Graph.vertices(residue) == [] && :solved) || {:stable, residue} end)
  end

  ## Wake up propagators based on the changes
  defp wakeup(changes, constraint_graph) when is_map(changes) do
    Enum.reduce(changes, [], fn {var_id, change}, acc ->
      acc ++ ConstraintGraph.get_propagators(constraint_graph, var_id, change)
    end)
  end

  defp filter_propagators_by_ids(ids, propagators) do
    Map.take(propagators, ids)
  end

  defp remove_fixed_variables(graph, vars) do
    Enum.reduce(vars, graph, fn v, acc ->
      if Variable.fixed?(v) do
        ConstraintGraph.remove_variable(acc, v.id)
      else
        acc
      end
    end)
  end

  defp remove_entailed_propagators(constraint_graph) do
    Enum.reduce(Graph.vertices(constraint_graph), constraint_graph, fn v, acc ->
      (Graph.neighbors(acc, v) == [] && Graph.delete_vertex(acc, v)) || acc
    end)
  end
end
