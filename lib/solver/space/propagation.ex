defmodule CPSolver.Space.Propagation do
  alias CPSolver.Propagator.ConstraintGraph
  alias CPSolver.Propagator
  import CPSolver.Common

  require Logger

  def run(constraint_graph, changes \\ %{})

  def run(constraint_graph, changes) do
    constraint_graph
    |> ConstraintGraph.get_propagators()
    |> then(fn propagators ->
      run_impl(
        propagators,
        constraint_graph,
        propagator_changes(constraint_graph, changes),
        reset?: true
      )
      |> finalize(changes)
    end)
  end



  defp run_impl(propagators, constraint_graph, domain_changes, opts) do
    case propagate(propagators, constraint_graph, domain_changes, opts) do
      {:fail, propagator_id} ->
        {:fail, propagator_id}

      {scheduled_propagators, reduced_graph, new_domain_changes} ->
        if MapSet.size(scheduled_propagators) == 0 do
          reduced_graph
        else
          run_impl(scheduled_propagators, reduced_graph, new_domain_changes, reset?: false)
        end
    end
  end

  def propagate(propagators, graph) do
    propagate(propagators, graph, [])
  end

  def propagate(propagators, graph, opts) do
    propagate(propagators, graph, Map.new(), opts)
  end

  @spec propagate(map(), Graph.t(), map(), Keyword.t()) ::
          {:fail, reference()} | {map(), Graph.t(), map()}
  @doc """
  A single pass of propagation.
  Produces the list (up to implementation) of propagators scheduled for the next pass.
  Side effect: modifies the constraint graph.
  The graph will be modified on every individual Propagator.filter/1, if the latter results in any domain changes.
  """
  def propagate(propagators, graph, domain_changes, opts) when is_list(propagators) do
    propagators
    |> Map.new(fn p -> {p.id, p} end)
    |> propagate(graph, domain_changes, opts)
  end

  def propagate(%MapSet{} = propagator_ids, graph, propagator_changes, opts) do
    Map.new(propagator_ids, fn p_id -> {p_id, ConstraintGraph.get_propagator(graph, p_id)} end)
    |> propagate(graph, propagator_changes, opts)
  end

  def propagate(propagators, graph, propagator_changes, opts) when is_map(propagators) do
    propagators
    |> reorder()
    |> Enum.reduce_while(
      {MapSet.new(), graph, Map.new()},
      fn
        {p_id, p}, {scheduled_acc, g_acc, changes_acc} = _acc ->
          reset? = opts[:reset?]

          p = (reset? && Propagator.bind(p, g_acc, :domain)) || p
          g_acc = ConstraintGraph.update_propagator(g_acc, p_id, p)
          |> tap(fn _ -> p_id != p.id && Logger.error("Propagator mismatch: #{inspect p_id} != #{inspect p.id}") end)

          res =
            Propagator.filter(p,
              reset?: reset?,
              changes: Map.get(propagator_changes, p_id),
              constraint_graph: g_acc
            )

          case res do
            {:filter_error, error} ->
              throw({:error, {:filter_error, error}})

            :fail ->
              {:halt, {:fail, p_id}}

            %{changes: no_changes, active?: active?} when no_changes in [nil, %{}] ->
              {:cont,
               {unschedule(scheduled_acc, p_id), maybe_remove_propagator(g_acc, p_id, active?),
                changes_acc}}

            %{changes: new_changes, active?: active?, state: state} ->
              {updated_graph, updated_scheduled, updated_changes} =
                update_schedule(
                  scheduled_acc,
                  changes_acc,
                  new_changes,
                  maybe_remove_propagator(g_acc, p_id, active?)
                )

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
          propagator_ids =
            ConstraintGraph.get_propagator_ids(g_acc, var_id, domain_change)

          {maybe_remove_variable(g_acc, var_id, domain_change),
           MapSet.union(
             propagators_acc,
             MapSet.new(Map.keys(propagator_ids))
           ), propagator_changes(propagator_ids, change, changes_acc)}
        end
      )

    {updated_graph, scheduled_propagators, cumulative_domain_changes}
  end

  ## Remove passive propagator
  defp maybe_remove_propagator(graph, propagator_id, active?) do
    (active? && graph) || ConstraintGraph.remove_propagator(graph, propagator_id)
  end

  defp finalize({:fail, _propagator_id} = failure, _changes) do
    failure
  end

  ## At this point, the space is either solved or stable.
  defp finalize(residual_graph, changes) do
    if Enum.empty?(ConstraintGraph.edges(residual_graph)) do
      :solved
    else
      residual_graph
      |> remove_fixed_variables(changes)
      |> then(fn g ->
        if Enum.empty?(ConstraintGraph.edges(g)) do
          :solved
        else
          {:stable, g}
        end
      end)
    end
  end

  defp maybe_remove_variable(graph, var_id, :fixed) do
    ConstraintGraph.disconnect_variable(graph, var_id)
  end

  defp maybe_remove_variable(graph, _var_id, _domain_change) do
    graph
  end

  defp unschedule(scheduled_propagators, p_id) do
    MapSet.delete(scheduled_propagators, p_id)
  end

  defp remove_fixed_variables(graph, changes) do
    Enum.reduce(changes, graph, fn {var_id, domain_change}, g_acc ->
      maybe_remove_variable(g_acc, var_id, domain_change)
    end)
  end

  ## TODO: possible reordering strategy
  ## for the next pass.
  ## Ideas:
  ## - Put to-be-entailed propagators first,
  ## so if they fail, it'd be early.
  ## - (extension of ^^) Order by the number of fixed variables
  ##
  defp reorder(propagators) do
    propagators
  end

  defp propagator_changes(graph, domain_changes) when is_map(domain_changes) do
    Enum.reduce(domain_changes, Map.new(), fn {var_id, domain_change} = change, changes_acc ->
      graph
      |> ConstraintGraph.get_propagator_ids(var_id, domain_change)
      |> propagator_changes(change, changes_acc)
    end)
  end

  defp propagator_changes(propagator_ids, {var_id, domain_change} = _change, changes_acc) do
    Enum.reduce(
      propagator_ids,
      changes_acc,
      fn {p_id, _p_data}, acc ->
        Map.update(acc, p_id, Map.new(%{var_id => domain_change}), fn var_map ->
          current_var_change = Map.get(var_map, var_id)

          Map.put(
            var_map,
            var_id,
            stronger_domain_change(current_var_change, domain_change)
          )
        end)
      end
    )
  end
end
