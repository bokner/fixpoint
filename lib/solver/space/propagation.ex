defmodule CPSolver.Space.Propagation do
  alias CPSolver.Propagator.ConstraintGraph
  alias CPSolver.Propagator

  def run(propagators, constraint_graph, store) do
    propagators
    |> run_impl(constraint_graph, store)
    |> finalize(propagators, store)
  end

  defp run_impl(propagators, constraint_graph, store) do
    case propagate(propagators, constraint_graph, store) do
      :fail ->
        :fail

      {scheduled_propagators, reduced_graph} ->
        (MapSet.size(scheduled_propagators) == 0 && reduced_graph) ||
          run_impl(scheduled_propagators, reduced_graph, store)
    end
  end

  @spec propagate(map(), Graph.t(), map()) ::
          :fail | {map(), Graph.t()} | {:changes, map()}
  @doc """
  A single pass of propagation.
  Produces the list (up to implementation) of propagators scheduled for the next pass.
  Side effect: modifies the constraint graph.
  The graph will be modified on every individual Propagator.filter/1, if the latter results in any domain changes.
  """

  def propagate(propagator_ids, graph, store) do
    propagator_ids
    |> Task.async_stream(
      fn p_id ->
        p = ConstraintGraph.get_propagator(graph, p_id)
        {p_id, p, Propagator.filter(p, store: store)}
      end,
      ## TODO: make it an option
      ##
      max_concurrency: 1
    )
    |> Enum.reduce_while({MapSet.new(), graph}, fn {:ok, {p_id, p, res}}, {scheduled, g} = _acc ->
      case res do
        :fail ->
          {:halt, :fail}

        :stable ->
          {:cont, {unschedule(scheduled, p_id), g}}

        %{changes: nil, active?: active?, state: new_state} ->
          {:cont,
           {unschedule(scheduled, p_id), maybe_remove_propagator(g, p_id, p, active?, new_state)}}

        %{changes: changes, state: state} ->
          {updated_graph, updated_scheduled} =
            update_schedule(scheduled, changes, g)

          {:cont,
           {updated_scheduled |> unschedule(p_id),
            ConstraintGraph.update_propagator(updated_graph, p_id, Map.put(p, :state, state))}}
      end
    end)
  end

  ## Note: we do not reschedule a propagator that was the source of domain changes,
  ## as we assume idempotence (that is, running a propagator for the second time wouldn't change domains).
  ## We will probably introduce the option to be used in propagator implementations
  ## to signify that the propagator is not idempotent.
  ##

  ## Returns set of propagator ids scheduled as a result of domain changes.
  defp update_schedule(current_schedule, domain_changes, graph) do
    {updated_graph, scheduled_propagators} =
      domain_changes
      |> Enum.reduce({graph, current_schedule}, fn {var_id, domain_change}, {g, propagators} ->
        {maybe_remove_variable(g, var_id, domain_change),
         MapSet.union(
           propagators,
           MapSet.new(ConstraintGraph.get_propagator_ids(g, var_id, domain_change))
         )}
      end)

    {updated_graph, scheduled_propagators}
  end

  ## TODO: revisit - remove passive propagators
  defp maybe_remove_propagator(graph, _propagator_id, _propagator, _active?, _new_state) do
    # new_state && ConstraintGraph.update_propagator(graph, propagator_id, Map.put(propagator, :state, new_state))
    # || graph
    graph
  end

  defp finalize(:fail, _propagators, _store) do
    :fail
  end

  ## At this point, the space is either solved or stable.
  defp finalize(%Graph{} = residual_graph, propagators, store) do
    if Enum.empty?(Graph.edges(residual_graph)) do
      (checkpoint(propagators, residual_graph, store) && :solved) || :fail
    else
      {:stable, remove_entailed_propagators(residual_graph, propagators)}
    end
  end

  defp checkpoint(propagators, graph, store) do
    Enum.reduce_while(propagators, true, fn p_id, acc ->
      p = ConstraintGraph.get_propagator(graph, p_id)

      case Propagator.filter(p, store: store) do
        :fail -> {:halt, false}
        _ -> {:cont, acc}
      end
    end)
  end

  defp remove_entailed_propagators(graph, propagators) do
    Enum.reduce(propagators, graph, fn p_id, g ->
      p_vertex = ConstraintGraph.propagator_vertex(p_id)

      case Graph.neighbors(g, p_vertex) do
        [] -> ConstraintGraph.remove_propagator(g, p_id)
        _connected_vars -> g
      end
    end)
  end

  defp maybe_remove_variable(graph, var_id, :fixed) do
    ConstraintGraph.remove_variable(graph, var_id)
  end

  defp maybe_remove_variable(graph, _var_id, _domain_change) do
    graph
  end

  defp unschedule(scheduled_propagators, p_id) do
    MapSet.delete(scheduled_propagators, p_id)
  end
end
