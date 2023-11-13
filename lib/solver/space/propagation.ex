defmodule CPSolver.Space.Propagation do
  alias CPSolver.Propagator.ConstraintGraph
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

      %{} ->
        :no_changes
    end)
  end

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
  end

  defp run_impl(active_propagators, constraint_graph, _store)
       when map_size(active_propagators) == 0 do
    finalize(constraint_graph)
  end

  defp run_impl(active_propagators, constraint_graph, store) do
    case propagate(active_propagators, store) do
      :fail ->
        :fail

      :no_changes ->
        finalize(constraint_graph)

      {:changed, changes} ->
        wakeup(changes, constraint_graph)
        |> then(fn {reduced_graph, active_propagators} ->
          run_impl(active_propagators, reduced_graph, store)
        end)
    end
  end

  ## At this point, the space is either solved or stable.
  defp finalize(constraint_graph) do
    (Graph.vertices(constraint_graph) == [] && :solved) ||
      {:fixpoint, constraint_graph}
  end

  ## Wake up propagators based on the changes
  defp wakeup(changes, constraint_graph) when is_map(changes) do
    changes
    |> Enum.reduce({constraint_graph, %{}}, fn {var_id, domain_change} = _var_change,
                                               {g, propagators_to_wakeup} ->
      {maybe_reduce_graph(g, var_id, domain_change),
       Map.merge(
         propagators_to_wakeup,
         Map.new(ConstraintGraph.get_propagators(constraint_graph, var_id, domain_change), fn p ->
           {p.id, p}
         end)
       )}
    end)
  end

  defp maybe_reduce_graph(graph, var_id, :fixed) do
    ConstraintGraph.remove_variable(graph, var_id)
  end

  defp maybe_reduce_graph(graph, _var_id, _domain_change) do
    graph
  end
end
