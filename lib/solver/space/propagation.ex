defmodule CPSolver.Space.Propagation do
  alias CPSolver.Propagator.ConstraintGraph
  alias CPSolver.Propagator

  def run(propagators, store \\ nil)

  def run(propagators, store) when is_list(propagators) do
    propagators
    |> Enum.map(fn p -> {make_ref(), p} end)
    |> Map.new()
    |> run(store)
  end

  def run(propagators, store) when is_map(propagators) and map_size(propagators) > 0 do
    run(propagators, ConstraintGraph.create(propagators), store)
  end

  def run(propagators, constraint_graph, store) when is_map(propagators) do
    propagators
    |> run_impl(constraint_graph, store)
    |> finalize(propagators)
  end

  defp run_impl(propagators, constraint_graph, _store) when map_size(propagators) == 0 do
    constraint_graph
  end

  defp run_impl(propagators, constraint_graph, store) do
    case propagate(propagators, store) do
      :fail ->
        :fail

      changes when map_size(changes) == 0 ->
        constraint_graph

      changes ->
        {reduced_graph, active_propagators} = wakeup(changes, constraint_graph)
        run_impl(active_propagators, reduced_graph, store)
    end
  end

  defp propagate(map, _store) when map_size(map) == 0 do
    :no_changes
  end

  @spec propagate(map(), map()) :: :fail | :no_changes | {:changes, map()}
  defp propagate(propagators, store) do
    propagators
    |> Task.async_stream(fn {_ref, p} -> Propagator.filter(p, store: store) end)
    |> Enum.reduce_while(%{}, fn {:ok, res}, acc ->
      case res do
        {:changed, changes} ->
          {:cont,
           Map.merge(acc, changes, fn _var, prev_event, new_event ->
             merge_events(prev_event, new_event)
           end)}

        :stable ->
          {:cont, acc}

        {:fail, _var} ->
          {:halt, :fail}
      end
    end)
  end

  defp finalize(:fail, _propagators) do
    :fail
  end

  ## At this point, the space is either solved or stable.
  ## Reduce constraint graph and interpret the result.
  defp finalize(%Graph{} = residue, propagators) do
    (Graph.vertices(residue) == [] && :solved) ||
      {:stable, residue, propagators_from_graph(residue, propagators)}
  end

  defp propagators_from_graph(graph, propagators) do
    Enum.reduce(propagators, Map.new(), fn {p_id, p}, acc ->
      (ConstraintGraph.get_propagator(graph, p_id) && Map.put(acc, p_id, p)) || acc
    end)
  end

  ## Wake up propagators based on the changes
  defp wakeup(changes, graph) when is_map(changes) do
    changes
    |> Enum.reduce({graph, %{}}, fn {var_id, domain_change}, {g, propagators} ->
      {maybe_remove_variable(g, var_id, domain_change),
       Map.merge(
         propagators,
         Map.new(
           ConstraintGraph.get_propagators(g, var_id, domain_change),
           fn p -> {p.id, p} end
         )
       )}
    end)
  end

  defp maybe_remove_variable(graph, var_id, :fixed) do
    ConstraintGraph.remove_variable(graph, var_id)
  end

  defp maybe_remove_variable(graph, _var_id, _domain_change) do
    graph
  end

  defp merge_events(prev_event, new_event) when prev_event == :fixed or new_event == :fixed do
    :fixed
  end

  ## TODO! Use hierarchy (i.e. fixed -> (min__change or max_change) -> bound_change -> domain_change)
  defp merge_events(_prev_event, new_event) do
    new_event
  end
end
