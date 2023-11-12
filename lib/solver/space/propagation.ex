defmodule CPSolver.Space.Propagation do
  alias CPSolver.Propagator.ConstraintGraph
  alias CPSolver.Variable
  alias CPSolver.Propagator

  defp propagate(map, _store) when map_size(map) == 0 do
    :no_changes
  end

  @spec propagate(map(), map()) :: :fail | :no_changes | {:changes, map()}
  defp propagate(propagators, store) do
    propagators
    |> Task.async_stream(fn {_ref, p} -> Propagator.filter(p, store: store) end)
    |> Enum.reduce_while(%{}, fn {:ok, res}, acc ->
      case res do
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

  def run(propagators, variables, store \\ nil)

  def run(propagators, variables, store) when is_list(propagators) do
    propagators
    |> Enum.map(fn p -> {make_ref(), p} end)
    |> Map.new()
    |> run(variables, store)
  end

  def run(propagators, variables, store) when is_map(propagators) and map_size(propagators) > 0 do
    run(propagators, variables, ConstraintGraph.create(propagators), store)
  end

  def run(propagators, variables, constraint_graph, store) when is_map(propagators) do
    propagators
    |> run_impl(constraint_graph, store)
    |> finalize(constraint_graph, propagators, variables)
  end

  defp run_impl(propagators, _constraint_graph, _store) when map_size(propagators) == 0 do
    :no_changes
  end

  defp run_impl(propagators, constraint_graph, store) do
    case propagate(propagators, store) do
      :fail ->
        :fail

      :no_changes ->
        :no_changes

      {:changed, changes} ->
        wakeup(changes, constraint_graph)
        |> run_impl(constraint_graph, store)
    end
  end

  defp finalize(:fail, _constraint_graph, _propagators, _variables) do
    :fail
  end

  ## At this point, the space is either solved or stable.
  ## Reduce constraint graph and interpret the result.
  defp finalize(:no_changes, constraint_graph, propagators, variables) do
    remove_fixed_variables(constraint_graph, variables)
    |> remove_entailed_propagators()
    |> then(fn {removed_propagator_ids, residue} ->
      (Graph.vertices(residue) == [] && :solved) ||
        {:stable, residue, Map.drop(propagators, removed_propagator_ids)}
    end)
  end

  ## Wake up propagators based on the changes
  defp wakeup(changes, constraint_graph) when is_map(changes) do
    changes
    |> Enum.reduce(%{}, fn {var_id, change}, acc ->
      Map.merge(acc, Map.new(ConstraintGraph.get_propagators(constraint_graph, var_id, change)))
    end)
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
    Enum.reduce(Graph.vertices(constraint_graph), {[], constraint_graph}, fn
      {:propagator, id} = v, {removed_propagator_ids, graph} = acc ->
        (Graph.neighbors(graph, v) == [] &&
           {[id | removed_propagator_ids], Graph.delete_vertex(graph, v)}) || acc

      _v, acc ->
        acc
    end)
  end
end
