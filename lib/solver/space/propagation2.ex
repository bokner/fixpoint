defmodule CPSolver.Space.Propagation2 do
  alias CPSolver.Propagator.ConstraintGraph
  alias CPSolver.Propagator
  import CPSolver.Common

  @spec run(Graph.t(), map() | list()) :: :fail | :solved | {:stable, Graph.t()}
  def run(constraint_graph, propagators) when is_list(propagators) do
    propagate(constraint_graph, propagators)
  end

  def run(constraint_graph, events) when is_map(events) do
    propagate(constraint_graph, :maps.iterator(events) |> :maps.next())
  end

  ## This function head is for top space propagation.
  ## That is, we run filtering on the initial propagator list.
  ##
  defp propagate(constraint_graph, propagators) when is_list(propagators) do
    {new_changes, updated_constraint_graph} = propagation_pass(constraint_graph, propagators)
    propagate(updated_constraint_graph, new_changes)
  end

  defp propagate(constraint_graph, :none) do
    finalize(constraint_graph)
  end

  defp propagate(constraint_graph, {var_id, domain_change, rest_iterator}) do
    propagate(constraint_graph, {var_id, domain_change, rest_iterator}, Map.new())
  end

  defp propagate(constraint_graph, {var_id, domain_change, rest_iterator}, accumulated_changes) do
    constraint_graph
    |> apply_domain_change(var_id, domain_change, accumulated_changes)
    |> then(fn {new_changes, updated_graph} ->
      propagate(updated_graph, :maps.next(rest_iterator), new_changes)
    end)
  end

  defp finalize(constraint_graph) do
    :todo
  end

  defp apply_domain_change(constraint_graph, var_id, domain_change, accumulated_changes) do
    triggered_propagators =
      ConstraintGraph.propagators_by_variable(constraint_graph, var_id, domain_change)

    Enum.reduce_while(
      triggered_propagators,
      {maybe_update_domain_changes(var_id, domain_change, accumulated_changes),
       maybe_update_constraint_graph(constraint_graph, var_id, domain_change)},
      fn p, {changes_acc, g_acc} = acc ->
        filter_result = filter(p)
        case process_result(filter_result, p, acc) do
          :fail -> {:halt, :fail}
          other -> {:cont, other}
        end
        ## TODO: handle filtering results
        ## TODO: update accumulated changes with the result ()
        ## TODO: remove fixed variables
      end
    )
  end

  defp propagation_pass(constraint_graph, propagators) do
    Enum.reduce(
      propagators,
      constraint_graph,
      fn p, graph_acc ->
        ## TODO: revisit
        filter(p)
      end
    )
  end


  defp maybe_update_constraint_graph(graph, var_id, :fixed) do
    ConstraintGraph.remove_variable(graph, var_id)
  end

  defp maybe_update_constraint_graph(graph, _var_id, _domain_change) do
    graph
  end

  defp maybe_update_domain_changes(var_id, domain_change, accumulated_changes) do
    ## We update to the stronger of the incoming domain change
    ## and the one that has already been present in accumulated changes.
    stronger_change = stronger_domain_change(domain_change, Map.get(accumulated_changes, var_id))
    Map.put(accumulated_changes, var_id, stronger_change)
  end

  defp filter(
         %{
           propagator: propagator,
           arg_position: arg_position,
           domain_change: domain_change
         } = _p_map
       ) do
    Propagator.filter(propagator, changes: %{arg_position => domain_change})
  end

  defp filter(propagator) do
    Propagator.filter(propagator)
  end

  defp process_result({:filter_error, error}, _propagator, _acc) do
    throw({:error, {:filter_error, error}})
  end

  defp process_result(:fail, _propagator, _acc) do
    :fail
  end

  defp process_result(:stable, _propagator, acc) do
    acc
  end

  defp process_result(
         %{changes: filter_changes, state: new_state, active: active?},
         propagator,
         {changes_acc, graph_acc} = _acc
       ) do
    changes =
      if filter_changes && map_size(filter_changes) > 0 do
        merge_changes(filter_changes, changes_acc)
      else
        changes_acc
      end

    {changes, remove_or_update_propagator(graph_acc, propagator, new_state, active?)}
  end

  defp merge_changes(change_map1, change_map2) do
    :todo
  end

  defp remove_or_update_propagator(graph, p, state, active?) when active? do
    ConstraintGraph.update_propagator(graph, p.id, Map.put(p, :state, state))
  end

  defp remove_or_update_propagator(graph, p, _state, _active?) do
    ConstraintGraph.remove_propagator(graph, p.id)
  end
end
