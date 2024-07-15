defmodule CPSolver.Space.Propagation2 do
  alias CPSolver.Propagator.ConstraintGraph
  alias CPSolver.Propagator
  import CPSolver.Common

  @spec run(Graph.t(), map() | list(), Keyword.t()) :: :fail | :solved | {:stable, Graph.t()}

  ## This function head is for top space propagation.
  ## That is, we run filtering on the initial propagator list.
  ##
  def run(constraint_graph, propagators, opts) when is_list(propagators) do
    {new_changes, updated_constraint_graph} = first_pass(constraint_graph, propagators, opts)
    run(updated_constraint_graph, new_changes, opts)
  end

  def run(constraint_graph, events, opts) when is_map(events) do
    propagate(constraint_graph, :maps.iterator(events) |> :maps.next(), opts)
  end


  defp propagate(constraint_graph, :none, _opts) do
    finalize(constraint_graph)
  end

  defp propagate(constraint_graph, {var_id, domain_change, rest_iterator}, opts) do
    propagate(constraint_graph, {var_id, domain_change, rest_iterator}, Map.new(), opts)
  end

  defp propagate(constraint_graph, {var_id, domain_change, rest_iterator}, accumulated_changes, opts) do
    accumulated_changes = Map.delete(accumulated_changes, var_id)
    constraint_graph
    |> apply_domain_change(var_id, domain_change, accumulated_changes, opts)
    |> then(fn
      :fail ->
        finalize(:fail)

      {new_changes, updated_graph} ->
        propagate(updated_graph, :maps.next(rest_iterator), new_changes, opts)
    end)
  end

  defp propagate(graph, :none, accumulated_changes, opts) do
    run(graph, accumulated_changes, opts)
  end

  defp finalize(:fail) do
    :fail
  end

  defp finalize(residual_graph) do
    if Enum.empty?(Graph.edges(residual_graph)) do
      :solved
    else
      {:stable, residual_graph}
    end
  end

  defp apply_domain_change(constraint_graph, var_id, domain_change, accumulated_changes, opts) do
    triggered_propagators =
      ConstraintGraph.propagators_by_variable(constraint_graph, var_id, domain_change)


    Enum.reduce_while(
      triggered_propagators,
      {accumulated_changes,
       maybe_remove_variable(constraint_graph, var_id, domain_change)},
      fn p, {_changes_acc, _graph_acc} = acc ->
        filter(p, acc, opts)
      end
    )
  end

  defp first_pass(constraint_graph, propagators, opts) do
    Enum.reduce_while(
      propagators,
      {%{}, constraint_graph},
      fn p, {_changes_acc, _graph_acc} = acc ->
        filter(p, acc, opts)
      end
    )
  end

  defp maybe_remove_variable(graph, var_id, :fixed) do
    ConstraintGraph.remove_variable(graph, var_id)
  end

  defp maybe_remove_variable(graph, _var_id, _domain_change) do
    graph
  end

  defp filter(
         %{
           propagator: propagator,
           arg_position: arg_position,
           domain_change: domain_change
         } = _p_map,
         acc, opts
       ) do
    filter(propagator, %{arg_position => domain_change}, acc, opts)
  end

  defp filter(propagator, acc, opts) do
    filter(propagator, %{}, acc, opts)
  end

  defp filter(propagator, changes, acc, opts) do
    filter_result = Propagator.filter(propagator, changes: changes, store: opts[:store])

    case process_result(filter_result, propagator, acc) do
      :fail -> {:halt, :fail}
      other -> {:cont, other}
    end
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
         %{changes: filter_changes, state: new_state, active?: active?},
         propagator,
         {changes_acc, graph_acc} = _acc
       ) do
    {changes, updated_graph1} =
      if filter_changes && map_size(filter_changes) > 0 do
        {merge_changes(filter_changes, changes_acc),
         maybe_remove_fixed_vars(graph_acc, filter_changes)}
      else
        {changes_acc, graph_acc}
      end

    {changes, remove_or_update_propagator(updated_graph1, propagator, new_state, active?)}
  end

  defp merge_changes(change_map1, change_map2) do
    Map.merge(change_map1, change_map2, fn _var_id, domain_change1, domain_change2 ->
      stronger_domain_change(domain_change1, domain_change2)
    end)
  end

  defp remove_or_update_propagator(graph, p, state, active?) do
    (active? && !ConstraintGraph.entailed_propagator?(graph, p) &&
       ConstraintGraph.update_propagator(graph, p.id, Map.put(p, :state, state))) ||
      ConstraintGraph.remove_propagator(graph, p.id)
  end

  defp maybe_remove_fixed_vars(graph, changes) do
    Enum.reduce(changes, graph, fn {var_id, domain_change}, g_acc ->
      maybe_remove_variable(g_acc, var_id, domain_change)
    end)
  end
end
