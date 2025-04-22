defmodule CPSolver.Propagator.AllDifferent.DC do
  use CPSolver.Propagator

  alias CPSolver.Algorithms.Kuhn

  @moduledoc """
  The domain-consistent propagator for AllDifferent constraint,
  based on bipartite maximum matching.
  """
  @impl true
  def arguments(args) do
    Arrays.new(args, implementation: Aja.Vector)
  end

  @impl true
  def variables(args) do
    Enum.map(args, fn x_el -> set_propagate_on(x_el, :domain_change) end)
  end

  @impl true
  def filter(all_vars, state, changes) do
    new_state =
      (state && filter_impl(all_vars, state, changes)) ||
        initial_state(all_vars)

    (new_state == :resolved && :passive) ||
      {:state, new_state}
  end

  defp filter_impl(_all_vars, state, changes) when is_nil(changes) or map_size(changes) == 0 do
    state
  end

  defp filter_impl(
         all_vars,
         %{
           sccs: sccs
         } =
           _state,
         changes
       ) do
    ## Apply changes to affected SCCs
    trigger_vars =
      Map.keys(changes) |> MapSet.new()

    Enum.reduce(sccs, [], fn %{component: component} = component_rec, sccs_acc ->
      component_triggers = MapSet.intersection(trigger_vars, component)

      if MapSet.size(component_triggers) == 0 do
        [component_rec | sccs_acc]
      else
        update_component(all_vars, component_rec) ++ sccs_acc
      end
    end)
    |> final_state()
  end

  defp update_component(
         all_vars,
         %{value_graph: value_graph, component: component} = component_rec
       ) do
    ## We will mostly do what initial reduction does, but on a (lesser) subset of variables
    ## that is represented by a component.
    ## TODO:
    ## The difference is that we'll only run maximum matching
    ## if any of the trigger variables doesn't have the value associated with the matching edge.

    {component_variable_map, repair_matching?} = component_variables(component_rec, all_vars)
    value_graph = update_value_graph(component_variable_map, value_graph)

    ## If matching hasn't changed, reuse;
    ## otherwise, start with partial matching built from fixed variables.
    matching = (repair_matching? && %{}) || component_rec[:matching]

    {_residual_graph, sccs} =
      reduction(
        all_vars,
        value_graph,
        MapSet.new(component, fn var_id -> {:variable, var_id} end),
        matching,
        repair_matching?
      )

    sccs
  end

  ## Pick out variables that match component's var ids;
  ## Also flags if there is any element in matching
  ## that does not have it's value in the domain of variable it previously matched.
  defp component_variables(%{matching: matching} = _component_rec, vars) do
    Enum.reduce(matching, {Map.new(), false}, fn {{:value, matching_value}, {:variable, var_id}},
                                                 {map_acc, matching_acc} ->
      var = Propagator.arg_at(vars, var_id)

      {
        Map.put(map_acc, var_id, var),
        ## If match is still there, reuse it (will be in partial matching for the next step)

        matching_acc || !contains?(var, matching_value)
      }
    end)
  end

  def initial_state(vars) do
    {value_graph, variable_vertices, partial_matching} = build_value_graph(vars)
    {_residual_graph, sccs} = reduction(vars, value_graph, variable_vertices, partial_matching)
    final_state(sccs)
  end

  def final_state(sccs) do
    (Enum.empty?(sccs) && :resolved) ||
      %{
        sccs: sccs
      }
  end

  def reduction(vars, value_graph, variable_vertices, partial_matching, repair_matching? \\ true) do
    maximum_matching =
      (repair_matching? &&
         compute_maximum_matching(value_graph, variable_vertices, partial_matching)) ||
        partial_matching

    {residual_graph, sccs} =
      build_residual_graph(value_graph, maximum_matching)
      |> reduce_residual_graph(vars)

    {residual_graph, localize_state(sccs, value_graph, maximum_matching)}
  end

  def build_value_graph(var_list) do
    Enum.reduce(var_list, {0, Map.new()}, fn var, {idx_acc, map_acc} ->
      {idx_acc + 1, Map.put(map_acc, idx_acc, var)}
    end)
    |> elem(1)
    |> build_value_graph_impl()
  end

  def build_value_graph_impl(variable_map) when is_map(variable_map) do
    Enum.reduce(
      variable_map,
      {BitGraph.new(), MapSet.new(), Map.new()},
      fn {var_id, var}, {graph_acc, var_vertices_acc, partial_matching_acc} ->
        var_vertex = {:variable, var_id}
        var_vertices_acc = MapSet.put(var_vertices_acc, var_vertex)

        fixed? = fixed?(var)

        partial_matching_acc =
          if fixed? do
            Map.put(partial_matching_acc, {:value, min(var)}, var_vertex)
          else
            partial_matching_acc
          end

        graph_acc  =
            Enum.reduce(domain_values(var), graph_acc, fn d, graph_acc2 ->
              BitGraph.add_edge(graph_acc2, {:value, d}, var_vertex)
          end)

        {graph_acc, var_vertices_acc, partial_matching_acc}
      end
    )
  end


  defp update_value_graph(variable_map, value_graph) do
    Enum.reduce(variable_map, value_graph, fn {var_id, var}, graph_acc ->
      variable_vertex = {:variable, var_id}

      if BitGraph.in_degree(value_graph, variable_vertex) > size(var) do
        ## There are some edges to delete
        Enum.reduce(BitGraph.in_edges(graph_acc, variable_vertex), graph_acc, fn %{from: {:value, val}} =
                                                                                edge,
                                                                              g_acc2 ->
          (contains?(var, val) && g_acc2) || BitGraph.delete_edge(g_acc2, edge)
        end)
      else
        graph_acc
      end
    end)

    end

  def compute_maximum_matching(value_graph, variable_ids, partial_matching) do
    Kuhn.run(value_graph, variable_ids, partial_matching, MapSet.size(variable_ids))
    || fail()
  end

  defp build_residual_graph(value_graph, maximum_matching) do
    ## The matching edges connect variables to values
    Enum.reduce(
      BitGraph.edges(value_graph),
      value_graph,
      fn %{
           from: {:value, _value} = v1,
           to: {:variable, _var_id} = v2
         } = _edge,
         residual_graph_acc ->
        case Map.get(maximum_matching, v1) do
          nil ->
            ## The vertices of unmatched values are connected to the sink vertex
            BitGraph.add_edge(residual_graph_acc, :sink, v1)

          ## The edge is in matching - reverse
          var when var == v2 ->
            BitGraph.delete_edge(residual_graph_acc, v1, v2)
            |> BitGraph.add_edge(v2, v1)
            |> BitGraph.add_edge(v1, :sink)

          _var ->
            ## For values in the domain, but not in matching, keep value -> variable edge
            residual_graph_acc
        end
      end
    )
  end

  defp reduce_residual_graph(residual_graph, vars) do
    sccs = BitGraph.strong_components(residual_graph) |> sccs_to_sets()
    residual_graph = remove_cross_edges(residual_graph, sccs, vars)
    {residual_graph, postprocess_sccs(sccs)}
  end

  defp sccs_to_sets(sccs_arrays) do
    Enum.map(sccs_arrays, fn component -> MapSet.delete(component, :sink) end)
  end

  ## Move parts of matching to where SCCs they belong to are
  defp localize_state(sccs, value_graph, matching) do
    ## Matching is value => var_id map
    ## We want to reverse it, so we can do a lookup by var_id later on
    matching_map =
      Enum.reduce(matching, Map.new(), fn {{:value, value}, {:variable, var_id}}, map_acc ->
        Map.put(map_acc, var_id, value)
      end)

    ## Build records with list of variable ids and atached matching for SCCs
    Enum.reduce(sccs, [], fn component, acc ->
      if MapSet.size(component) <= 1 do
        ## We don't have to handle components with less than 2 variables
        acc
      else
        {m, v_graph} =
          Enum.reduce(component, {Map.new(), BitGraph.new()}, fn var_id,
                                                              {matching_acc, value_graph_acc} =
                                                                acc ->
            case Map.get(matching_map, var_id) do
              nil ->
                acc

              value ->
                variable_vertex = {:variable, var_id}
                value_edges = BitGraph.in_edges(value_graph, variable_vertex)
                ## We keep matching in the original form so we can reuse it
                ## in in the consequent iterations
                {
                  Map.put(matching_acc, {:value, value}, variable_vertex),
                  BitGraph.add_edges(value_graph_acc, value_edges)
                }
            end
          end)

        [%{matching: m, component: component, value_graph: v_graph} | acc]
      end
    end)
  end

  defp remove_cross_edges(residual_graph, [_single_component] = _sccs, _vars) do
    residual_graph
  end

  defp remove_cross_edges(residual_graph, sccs, vars) do
    Enum.reduce(sccs, residual_graph, fn vertices, graph_acc ->
      Enum.reduce(vertices, graph_acc, fn
        {:variable, _var_id} = variable_vertex, graph_acc2 ->
          edges = BitGraph.in_edges(graph_acc2, variable_vertex)

          Enum.reduce(edges, graph_acc2, fn
            %{from: {:value, value} = value_vertex} = _edge, graph_acc3 ->
              (value_vertex in vertices && graph_acc3) ||
                BitGraph.delete_edge(graph_acc3, value_vertex, variable_vertex)
                |> tap(fn _ ->
                  ## If this is 'value -> variable' edge, remove the value from the domain of variable
                  maybe_remove_domain_value(value, variable_vertex, vars)
                end)

            _non_value_vertex, graph_acc3 ->
              graph_acc3
          end)

        _non_variable_vertex, graph_acc2 ->
          graph_acc2
      end)
    end)
  end

  defp maybe_remove_domain_value(value, {:variable, var_id}, vars) do
    Propagator.arg_at(vars, var_id) |> remove(value)
  end

  defp maybe_remove_domain_value(_value, :sink, _vars) do
    :ignore
  end

  defp postprocess_sccs(sccs) do
    Enum.reduce(sccs, [], fn
      ## Drop single-element components
      [_single], acc ->
        acc

      component, acc ->
        ## Turn non-singleton SCC to the set to speed up the lookups
        ## in consequent filtering calls.
        ## Drop 'value' vertices from SCC.
        [
          Enum.reduce(component, MapSet.new(), fn
            {:variable, var_id} = _var_vertex, component_acc ->
              MapSet.put(component_acc, var_id)

            _non_var_vertex, map_acc ->
              map_acc
          end)
          | acc
        ]
    end)
  end

  defp fail() do
    throw(:fail)
  end

end
