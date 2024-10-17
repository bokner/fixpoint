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

  defp filter_impl(
         all_vars,
          %{
            sccs: sccs
        } =
          _state,
         changes
       ) do
        #initial_state(all_vars)
    ## Apply changes to affected SCCs
    trigger_vars =
       Map.keys(changes) |> MapSet.new()

     Enum.reduce(sccs, [], fn component, sccs_acc ->
       component_triggers = MapSet.intersection(trigger_vars, component)
       if MapSet.size(component_triggers) == 0 do
         [component | sccs_acc]
       else
         apply_triggers(all_vars, component, component_triggers) ++ sccs_acc
       end
     end)
    |> final_state()
  end

  defp apply_triggers(all_vars, component, _trigger) do
    ## We will mostly do what initial reduction does, but on a (lesser) subset of variables
    ## that is represented by a component.
    ## TODO:
    ## The difference is that we'll only run maximum matching
    ## if any of the trigger variables doesn't have the value associated with the matching edge.

    ## TODO: indexing of component variables?
    ## (i.e., preserve position of component variable in the all_vars list)
    component_variable_map = component_variables(component, all_vars)
    {value_graph, variable_vertices, partial_matching} = build_value_graph(component_variable_map)
    {_residual_graph, sccs, _matching} = reduction(all_vars, value_graph, variable_vertices, partial_matching)
    sccs
  end

  ## Pick out variables that match component's var ids
  defp component_variables(component, vars) do
    Map.new(component, fn var_id -> {var_id, Propagator.arg_at(vars, var_id)} end)
  end

  def initial_state(vars) do
    {value_graph, variable_vertices, partial_matching} = build_value_graph(vars)
    {_residual_graph, sccs, _matching} = reduction(vars, value_graph, variable_vertices, partial_matching)
    final_state(sccs)
  end

  def final_state(sccs) do
    (Enum.empty?(sccs) && :resolved) ||
    %{
      sccs: sccs
    }
  end

  def reduction(vars, value_graph, variable_vertices, partial_matching) do
    maximum_matching = compute_maximum_matching(value_graph, variable_vertices, partial_matching)

    {residual_graph, sccs} =
      build_residual_graph(value_graph, maximum_matching)
      |> reduce_residual_graph(vars)

    {residual_graph, sccs, maximum_matching}

  end

  def build_value_graph(var_list) when is_struct(var_list, Aja.Vector) do
    Arrays.reduce(var_list, {0, Map.new()}, fn var, {idx_acc, map_acc} ->
      {idx_acc + 1, Map.put(map_acc, idx_acc, var)}
    end)
    |> elem(1)
    |> build_value_graph()
  end

  def build_value_graph(variable_map) when is_map(variable_map) do
    Enum.reduce(variable_map,
      {Graph.new(), [], Map.new()},
      fn {var_id, var}, {graph_acc, var_ids_acc, partial_matching_acc} ->
        var_vertex = {:variable, var_id}
        var_ids_acc = [var_vertex | var_ids_acc]
        partial_matching_acc =
          if fixed?(var) do
            Map.put(partial_matching_acc, {:value, min(var)}, var_vertex)
          else
            partial_matching_acc
          end

        domain = domain(var) |> Domain.to_list()

        graph_acc =
          Enum.reduce(domain, graph_acc, fn d, graph_acc2 ->
            Graph.add_edge(graph_acc2, {:value, d}, var_vertex)
          end)

        {graph_acc, var_ids_acc, partial_matching_acc}
      end
    )
  end

  def compute_maximum_matching(value_graph, variable_ids, partial_matching) do
    Kuhn.run(value_graph, variable_ids, partial_matching)
    |> tap(fn matching -> map_size(matching) < length(variable_ids) && fail() end)
  end

  defp build_residual_graph(value_graph, maximum_matching) do
    ## The matching edges connect variables to values
    Enum.reduce(
      Graph.edges(value_graph),
      value_graph,
      fn %{
           v1: {:value, _value} = v1,
           v2: {:variable, _var_id} = v2
         } = _edge,
         residual_graph_acc ->
        case Map.get(maximum_matching, v1) do
          nil ->
            ## The vertices of unmatched values are connected to the sink vertex
            Graph.add_edge(residual_graph_acc, :sink, v1)

          ## The edge is in matching - reverse
          var when var == v2 ->
            Graph.delete_edge(residual_graph_acc, v1, v2)
            |> Graph.add_edge(v2, v1)
            |> Graph.add_edge(v1, :sink)

          _var ->
            ## For values in the domain, but not in matching, keep value -> variable edge
            residual_graph_acc
        end
      end
    )
  end

  defp reduce_residual_graph(graph, vars) do
    sccs = Graph.strong_components(graph)
    {remove_cross_edges(graph, sccs, vars), postprocess_sccs(sccs)}
  end

  defp remove_cross_edges(graph, [_single_component] = _sccs, _vars) do
    graph
  end

  defp remove_cross_edges(graph, sccs, vars) do
    vertices_to_sccs = map_vertices_to_sccs(sccs)
    ## Remove edges that have vertices in different SCCs
    graph
    |> Graph.edges()
    |> Enum.reduce(
      graph,
      fn
        %{v1: {:value, value} = v1, v2: v2} = _edge, graph_acc ->
          if Map.get(vertices_to_sccs, v1) != Map.get(vertices_to_sccs, v2) do
            ## Cross-edge, remove
            Graph.delete_edge(graph_acc, v1, v2)
            |> tap(fn _ ->
              ## If this is 'value -> variable' edge, remove the value from the domain of variable
              maybe_remove_domain_value(value, v2, vars)
            end)
          else
            graph_acc
          end

        _non_value_edge, graph_acc ->
          graph_acc
      end
    )
  end

  defp maybe_remove_domain_value(value, {:variable, var_id}, vars) do
    Propagator.arg_at(vars, var_id) |> remove(value)
  end

  defp maybe_remove_domain_value(_value, :sink, _vars) do
    :ignore
  end

  defp map_vertices_to_sccs(sccs) do
    Enum.reduce(
      sccs,
      Map.new(),
      fn component, map_acc ->
        scc_ref = make_ref()

        Enum.reduce(component, map_acc, fn vertex, map_acc2 ->
          Map.put(map_acc2, vertex, scc_ref)
        end)
      end
    )
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
        [Enum.reduce(component, MapSet.new(), fn {:variable, var_id} = _var_vertex, component_acc ->
          MapSet.put(component_acc, var_id)
          _non_var_vertex, map_acc -> map_acc

        end) | acc]
    end)
  end

  defp fail() do
    throw(:fail)
  end

  alias CPSolver.IntVariable, as: Variable

  def test(domains) do
    vars =
      Enum.map(Enum.with_index(domains, 1), fn {d, idx} -> Variable.new(d, name: "x#{idx}") end)

    {:ok, vars, _store} = CPSolver.ConstraintStore.create_store(vars)

    initial_state(vars)
    |> tap(fn _ ->
      IO.inspect(
        Enum.map(vars, fn var -> {var.name, Interface.domain(var) |> Domain.to_list()} end)
      )
    end)
  end
end
