defmodule CPSolver.Space.Propagation2 do
  alias CPSolver.Propagator.ConstraintGraph
  import CPSolver.Common

  def run(constraint_graph, events) when is_map(events) do
    run_impl(constraint_graph, :maps.iterator(events) |> :maps.next())
  end

  defp run_impl(constraint_graph, :none) do
    finalize(constraint_graph)
  end

  defp run_impl(constraint_graph, {var_id, domain_change, rest_iterator}) do
    constraint_graph
    |> apply_domain_change(var_id, domain_change)
    |> run_impl(:maps.next(rest_iterator))
  end

  defp finalize(constraint_graph) do
    :todo
  end

  defp apply_domain_change(constraint_graph, var_id, domain_change) do
    triggered_propagators = ConstraintGraph.propagators_by_variable(constraint_graph, var_id, domain_change)
    Enum.reduce(triggered_propagators, constraint_graph, fn propagator, graph_acc ->
      result = propagate(propagator, var_id, domain_change)
      update_constraint_graph(graph_acc, result)
    end)
  end

  defp update_constraint_graph(constraint_graph, propagation_result) do
    :todo
  end

  defp propagate(propagator, var_id, domain_change) do

  end



  ## The list of tuples {propagator, events}.
  ## Given the map of events {variable_id => domain_change}
  ## derive the propagators triggered by these events.

  defp get_triggered_propagators(events, constraint_graph) when is_map(events) do
    Enum.reduce(events, Map.new(), fn {var_id, domain_change}, propagators_acc ->
      p_ids = ConstraintGraph.propagators_by_variable(constraint_graph, var_id, domain_change)
      Map.merge(propagators_acc, p_ids, fn p_id, incoming_events, propagator_data ->
        Map.put(incoming_events, var_id, propagator_data.arg_position)
      end)
    end)
  end

  defp get_all_propagators(constraint_graph) do

  end





  defp propagator_changes(propagator_ids, {_var_id, domain_change} = _change, changes_acc) do
    Enum.reduce(
      propagator_ids,
      changes_acc,
      fn {p_id, p_data}, acc ->
        arg_position = p_data.arg_position

        Map.update(acc, p_id, Map.new(%{arg_position => domain_change}), fn var_map ->
          current_var_change = Map.get(var_map, arg_position)

          Map.put(
            var_map,
            arg_position,
            maybe_update_domain_change(current_var_change, domain_change)
          )
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

  defp maybe_update_domain_change(_current_change, :domain_change) do
    :domain_change
  end

  defp maybe_update_domain_change(:bound_change, bound_change)
       when bound_change in [:min_change, :max_change] do
    bound_change
  end

  defp maybe_update_domain_change(bound_change, :bound_change)
       when bound_change in [:min_change, :max_change] do
    bound_change
  end

  defp maybe_update_domain_change(:min_change, :max_change) do
    :bound_change
  end

  defp maybe_update_domain_change(:max_change, :min_change) do
    :bound_change
  end

  defp maybe_update_domain_change(current_change, new_change) when current_change == new_change do
    current_change
  end

end
