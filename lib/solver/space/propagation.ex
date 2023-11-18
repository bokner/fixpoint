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
    case propagate(propagators, constraint_graph, store) do
      :fail ->
        :fail

      {scheduled_propagators, reduced_graph} ->
        run_impl(scheduled_propagators, reduced_graph, store)
    end
  end

  @spec propagate(map(), Graph.t(), map()) :: :fail | {map(), Graph.t()} | {:changes, map()}
  @doc """
  One pass of propagation.
  Produces the list (up to implementation) of propagators scheduled for the next pass.
  Side effect: modifies the constraint graph.
  The graph will be modified on every individual Propagator.filter/1, if the latter results in any domain changes.
  """

  def propagate(propagators, graph, store) do
    propagators
    |> Task.async_stream(fn {p_id, p} ->
      {p_id, Propagator.filter(p, store: store)}
    end)
    |> Enum.reduce_while({Map.new(), graph}, fn {:ok, {p_id, res}}, {scheduled, g} = acc ->
      case res do
        {:fail, _var} ->
          {:halt, :fail}

        {:changed, changes} ->
          {updated_graph, scheduled_by_propagator} = schedule(p_id, changes, g)

          {:cont,
           {
             Map.merge(scheduled_by_propagator, scheduled),
             updated_graph
           }}

        :stable ->
          {:cont, acc}
      end
    end)
  end

  ## Note: we do not reschedule a propagator that was the source of domain changes,
  ## as we assume idempotence (that is, running propagator for the second time wouldn't change domains).
  ## We will probably introduce the option to be used in propagator implementations
  ## to signify that the propagator is not idempotent.
  ##
  defp schedule(source_id, domain_changes, graph) do
    {updated_graph, scheduled_propagators} =
      domain_changes
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

    {updated_graph, Map.delete(scheduled_propagators, source_id)}
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

  defp maybe_remove_variable(graph, var_id, :fixed) do
    ConstraintGraph.remove_variable(graph, var_id)
  end

  defp maybe_remove_variable(graph, _var_id, _domain_change) do
    graph
  end
end
