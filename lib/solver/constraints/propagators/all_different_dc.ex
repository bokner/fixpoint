defmodule CPSolver.Propagator.AllDifferent.DC do
  use CPSolver.Propagator

  @moduledoc """
  The domain-consistent propagator for AllDifferent constraint,
  based on bipartite maximum matching.
  """

  defp initial_state(args) do
    {partial_matching, residual_graph, unfixed_ids} =
      args
      |> Enum.sort_by(fn var -> Interface.size(var) end)
      |> Enum.with_index()
      |> Enum.reduce(
        {MapSet.new(), Graph.new(), []},
        fn {var, idx}, {matching_acc, graph_acc, unfixed_acc} ->
          if fixed?(var) do
            val = min(var)

            {
              ## Fail if the value is already in matching
              (MapSet.member?(matching_acc, val) && fail()) || MapSet.put(matching_acc, val),
              Graph.add_edge(graph_acc, idx, val),
              unfixed_acc
            }
          else
            {matching_acc, add_edges(graph_acc, idx, domain(var) |> Domain.to_list()),
             [idx | unfixed_acc]}
          end
        end
      )

    %{
      partial_matching: partial_matching,
      residual_graph: residual_graph,
      unfixed_ids: unfixed_ids
    }
  end

  defp add_edges(graph, vertex, neighbours) do
    Enum.reduce(neighbours, graph, fn n, g_acc -> Graph.add_edge(g_acc, vertex, n) end)
  end

  @impl true
  def variables(args) do
    Enum.map(args, fn x_el -> set_propagate_on(x_el, :domain_change) end)
  end

  @impl true
  def filter(args, nil, changes) do
    filter(args, initial_state(args), changes)
  end

  @impl true
  def filter(all_vars, %{unfixed_ids: []} = _state, _changes) do
    :passive
  end

  def filter(all_vars, %{unfixed_ids: unfixed_ids} = _state, _changes) do
    updated_unfixed_vars = filter_impl(all_vars, unfixed_ids)
    {:state, %{unfixed_ids: updated_unfixed_vars}}
  end

  defp filter_impl(all_vars, unfixed_vars) do
    fwc(all_vars, unfixed_vars, MapSet.new(), [], false)
  end

  ## The list of unfixed variables exhausted, and there were no fixed values.
  ## We stop here
  defp fwc(_all_vars, [], _fixed_values, unfixed_ids, false) do
    unfixed_ids
  end

  ## The list of unfixed variables exhausted, and some new fixed values showed up.
  ## We go through unfixed ids we have collected during previous stage again

  defp fwc(all_vars, [], fixed_values, ids_to_revisit, true) do
    fwc(all_vars, ids_to_revisit, fixed_values, [], false)
  end

  ## There is still some (previously) unfixed values to check
  defp fwc(all_vars, [idx | rest], fixed_values, ids_to_revisit, changed?) do
    var = Enum.at(all_vars, idx)
    remove_all(var, fixed_values)

    if fixed?(var) do
      ## Variable is fixed or was fixed as a result of removing all fixed values
      fwc(all_vars, rest, MapSet.put(fixed_values, min(var)), ids_to_revisit, true)
    else
      ## Still not fixed, put it to 'revisit' list
      fwc(all_vars, rest, fixed_values, [idx | ids_to_revisit], changed?)
    end
  end

  ## Remove values from the domain of variable
  defp remove_all(variable, values) do
    Enum.map(
      values,
      fn value ->
        remove(variable, value)
      end
    )
    |> Enum.any?(fn res -> res == :fixed end)
  end

  defp fail() do
    throw(:fail)
  end
end
