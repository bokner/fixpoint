defmodule CPSolver.Space.Propagation do
  alias CPSolver.Propagator.ConstraintGraph
  alias CPSolver.Propagator

  require Logger

  def run(propagators, constraint_graph, store) when is_list(propagators) do
    propagators
    |> run_impl(constraint_graph, store)
    |> finalize(propagators, store)
  end

  defp run_impl(propagators, constraint_graph, store) do
    run_impl(propagators, constraint_graph, store, Map.new())
  end

  defp run_impl(propagators, constraint_graph, store, domain_changes) do
    case propagate(propagators, constraint_graph, store, domain_changes) do
      :fail ->
        :fail

      {scheduled_propagators, reduced_graph, new_domain_changes} ->
        (MapSet.size(scheduled_propagators) == 0 && reduced_graph) ||
          run_impl(scheduled_propagators, reduced_graph, store, new_domain_changes)
    end
  end

  def propagate(propagators, graph, store) do
    propagate(propagators, graph, store, Map.new())
  end

  @spec propagate(map(), Graph.t(), map(), map()) ::
          :fail | {map(), Graph.t(), map()}
  @doc """
  A single pass of propagation.
  Produces the list (up to implementation) of propagators scheduled for the next pass.
  Side effect: modifies the constraint graph.
  The graph will be modified on every individual Propagator.filter/1, if the latter results in any domain changes.
  """

  def propagate(propagators, graph, store, domain_changes) when is_list(propagators) do
    propagators
    |> Map.new(fn p -> {p.id, p} end)
    |> propagate(graph, store, domain_changes)
  end

  def propagate(%MapSet{} = propagator_ids, graph, store, domain_changes) do
    Map.new(propagator_ids, fn p_id -> {p_id, ConstraintGraph.get_propagator(graph, p_id)} end)
    |> propagate(graph, store, domain_changes)
  end

  def propagate(propagators, graph, store, domain_changes) when is_map(propagators) do
    propagators
    |> reorder()
    |> Task.async_stream(
      fn {p_id, p} ->
        {p_id, p, Propagator.filter(p, store: store, changes: Map.get(domain_changes, p_id))}
      end,
      ## TODO: make it an option
      ##
      max_concurrency: 1
    )
    |> Enum.reduce_while(
      {MapSet.new(), graph, Map.new()},
      fn {:ok, {p_id, p, res}},
         {scheduled_acc, g_acc, changes_acc} =
           _acc ->
        case res do
          :fail ->
            {:halt, :fail}

          :stable ->
            {:cont, {unschedule(scheduled_acc, p_id), g_acc, changes_acc}}

          %{changes: nil, active?: active?, state: new_state} ->
            {:cont,
             {unschedule(scheduled_acc, p_id),
              maybe_remove_propagator(g_acc, p_id, p, active?, new_state), changes_acc}}

          %{changes: new_changes, state: state} ->
            {updated_graph, updated_scheduled, updated_changes} =
              update_schedule(scheduled_acc, changes_acc, new_changes, g_acc)

            {:cont,
             {updated_scheduled |> unschedule(p_id),
              ConstraintGraph.update_propagator(updated_graph, p_id, Map.put(p, :state, state)),
              updated_changes}}
        end
      end
    )
  end

  ## Note: we do not reschedule a propagator that was the source of domain changes,
  ## as we assume idempotence (that is, running a propagator for the second time wouldn't change domains).
  ## We will probably introduce the option to be used in propagator implementations
  ## to signify that the propagator is not idempotent.
  ##
  defp update_schedule(current_schedule, current_changes, new_domain_changes, graph) do
    {updated_graph, scheduled_propagators, cumulative_domain_changes} =
      new_domain_changes
      |> Enum.reduce(
        {graph, current_schedule, current_changes},
        fn {var_id, domain_change} = change, {g_acc, propagators_acc, changes_acc} ->
          propagator_ids = ConstraintGraph.get_propagator_ids(g_acc, var_id, domain_change)

          {maybe_remove_variable(g_acc, var_id, domain_change),
           MapSet.union(
             propagators_acc,
             MapSet.new(propagator_ids)
           ), propagator_changes(propagator_ids, change, changes_acc)}
        end
      )

    {updated_graph, scheduled_propagators, cumulative_domain_changes}
  end

  ## TODO: revisit - remove passive propagators
  defp maybe_remove_propagator(graph, propagator_id, propagator, active?, new_state) do
    (new_state && active? &&
       ConstraintGraph.update_propagator(
         graph,
         propagator_id,
         Map.put(propagator, :state, new_state)
       )) ||
      graph

    graph
  end

  defp finalize(:fail, _propagators, _store) do
    :fail
  end

  ## At this point, the space is either solved or stable.
  defp finalize(%Graph{} = residual_graph, propagators, store) do
    if Enum.empty?(Graph.edges(residual_graph)) do
      (checkpoint(propagators, store) && :solved) || :fail
    else
      {:stable, remove_entailed_propagators(residual_graph, propagators)}
    end
  end

  defp checkpoint(propagators, store) do
    Enum.reduce_while(propagators, true, fn p, acc ->
      case Propagator.filter(p, store: store) do
        :fail -> {:halt, false}
        _ -> {:cont, acc}
      end
    end)
  end

  defp remove_entailed_propagators(graph, propagators) do
    Enum.reduce(propagators, graph, fn p, g ->
      p_vertex = ConstraintGraph.propagator_vertex(p.id)

      case Graph.neighbors(g, p_vertex) do
        [] -> ConstraintGraph.remove_propagator(g, p.id)
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

  ## TODO: possible reordering strategy
  ## for the next pass.
  ## Ideas: put to-be-entailed propagators first,
  ## so if they fail, it'd be early.
  ## In general, arrange by the number of fixed variables?
  ##
  defp reorder(propagators) do
    propagators
  end

  defp propagator_changes(propagator_ids, {var_id, domain_change} = change, changes_acc) do
    Enum.reduce(
      propagator_ids,
      changes_acc,
      fn p_id, acc ->
        Map.update(acc, p_id, Map.new([change]), fn var_map ->
          current_var_change = Map.get(var_map, var_id)
          Map.put(var_map, var_id, maybe_update_domain_change(current_var_change, domain_change))
        end)
      end
    )
  end

  ## This is to "fold" all incoming changes for the propagator+variable into a single value.
  ## Reflects hierarchy of domain changes
  ##
  defp maybe_update_domain_change(nil, new_change) do
    new_change
  end

  defp maybe_update_domain_change(:fixed, _new_change) do
    :fixed
  end

  defp maybe_update_domain_change(_current_change, :fixed) do
    :fixed
  end

  defp maybe_update_domain_change(:domain_change, _new_change) do
    :domain_change
  end

  defp maybe_update_domain_change(:min_change, :max_change) do
    :bound_change
  end

  defp maybe_update_domain_change(current_change, new_change) when current_change == new_change do
    current_change
  end
end
