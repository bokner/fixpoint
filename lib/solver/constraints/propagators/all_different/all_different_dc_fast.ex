defmodule CPSolver.Propagator.AllDifferent.DC.Fast do
  @moduledoc """
  A Fast Algorithm for Generalized Arc Consistency of the Alldifferent Constraint
  Xizhe Zhang, Qian Li and Weixiong Zhang
  https://www.ijcai.org/proceedings/2018/0194.pdf
  """

  use CPSolver.Propagator

  alias CPSolver.Propagator.AllDifferent.DC
  alias CPSolver.Variable.Interface
  alias CPSolver.Algorithms.Kuhn
  alias CPSolver.Utils


  @impl true
  def arguments(args) do
    Arrays.new(args, implementation: Aja.Vector)
  end

  @impl true
  def variables(args) do
    Enum.map(args, fn x_el -> set_propagate_on(x_el, :domain_change) end)
  end

  @impl true
  def filter(vars, state, changes) do
    new_state =
      (state && filter_impl(update_variables(state, vars), changes)) ||
        initial_reduction(vars)

    (new_state == :resolved && :passive) ||
      {:state, new_state}
  end

  def filter_impl(state, changes) do
    updated_state = apply_changes(state, changes)

    case updated_state.components do
      0 -> :resolved
      _num_active_components -> updated_state
    end
  end

  def initial_reduction(vars) do
    initial_state = initial_state(vars)
    reduce_state(initial_state)
  end

  def initial_state(variables) do
    {value_graph, variable_vertices, partial_matching} =
      DC.build_value_graph(variables)

    %{
      value_graph: value_graph,
      variable_vertices: variable_vertices,
      matching: partial_matching
    }
    |> update_variables(variables)
  end

  defp update_variables(state, variables) do
    state
    |> Map.put(:variables, variables)
    |> Map.put(:reduction_callback,
      fn var_idx, value ->
        Interface.remove(Propagator.arg_at(variables, var_idx), value)
      end
    )
  end

  def reduce_state(%{
        value_graph: value_graph,
        matching: partial_matching,
        variable_vertices: variable_vertices,
        reduction_callback: reduction_callback
      } = state) do
    Map.merge(state,
    reduce_impl(
      value_graph,
      variable_vertices,
      partial_matching,
      reduction_callback
    ))
  end

  def find_matching(value_graph, variable_vertices, partial_matching) do
    Kuhn.run(
      value_graph,
      variable_vertices,
      partial_matching,
      MapSet.size(variable_vertices)
    )
    |> tap(fn matching -> matching || fail() end)
  end

  defp fail() do
    throw(:fail)
  end

  def reduce_impl(value_graph, variable_vertices, partial_matching, remove_edge_callback) do
    matching = find_matching(value_graph, variable_vertices, partial_matching)
    ## Flip edges that are in matching
    value_graph = flip_matching(value_graph, matching)

    ## Build sets Γ(A) (neighbors of free value vertices)
    ## and A (allowed nodes)
    ga_da_set = build_GA(value_graph, variable_vertices)

    value_graph
    |> remove_type1_edges(ga_da_set, remove_edge_callback)
    |> then(fn {t1_graph, complement_vertices} ->
      {value_graph, sccs, _vertices_to_scc_map} =
        remove_type2_edges(t1_graph, complement_vertices, remove_edge_callback)

      %{
        value_graph: value_graph,
        components: active_components_count(value_graph, matching, ga_da_set, sccs),
        matching: matching
      }
    end)
  end

  def apply_changes(state, changes) when is_nil(changes) or map_size(changes) == 0 do
    state
  end

  def apply_changes(state, changes) do
    ## Step 1: update value graph and matching.
    ## As a result of update, some variables could become unmatched
    {state, reduce_state?} = update_value_graph(state, changes)
    # IO.inspect({state, unmatched_variables}, label: :interim)
    ## Step 2: update components that contain unmatched variables.
    # state = update_components(vars, unmatched_variables, state, reduction_callback(vars))

    reduce_state? && reduce_state(state) || state

  end

  ## Update value graph based on domain changes
  def update_value_graph(
        %{value_graph: value_graph, matching: matching, variables: vars} = state,
        changes
      ) do
    {value_graph, matching, reduce_state?} =
      Enum.reduce(changes, {value_graph, matching, false}, fn {var_id, _domain_change},
                                                                     {graph_acc, _matching_acc,
                                                                      _reduce_state_acc?} = acc ->
        var_domain = Utils.domain_values(Propagator.arg_at(vars, var_id))
        variable_vertex = {:variable, var_id}

        Enum.reduce(Graph.edges(graph_acc, variable_vertex), acc, fn
          %{v1: variable_vertex, v2: {:value, value} = value_vertex},
          {graph_acc2, matching_acc2, reduce_state_acc2?} = _acc2 ->
            ## This is a 'matching' edge (out-edge of variable vertex)
            ##
            if value in var_domain do
              {graph_acc2, matching_acc2, reduce_state_acc2? || (MapSet.size(var_domain) == 1)}
            else
              ## Matching is no longer valid, the value has been removed
              {updated_graph, updated_matching} = repair_matching(graph_acc2, matching_acc2, var_id, value, var_domain)

              {Graph.delete_edge(updated_graph, variable_vertex, value_vertex), updated_matching,
               true}
            end

          %{v1: {:value, value} = value_vertex, v2: variable_vertex},
          {graph_acc2, matching_acc2, reduce_state_acc2?} = acc2 ->
            ## The edge is not in matching
            if value in var_domain do
              acc2
            else
              {Graph.delete_edge(graph_acc2, value_vertex, variable_vertex), matching_acc2,
               reduce_state_acc2?}
            end
        end)
      end)

    {state
     |> Map.put(:value_graph, value_graph)
     |> Map.put(:matching, matching), reduce_state?}
  end

  defp repair_matching(value_graph, matching, var_id, removed_value, variable_domain) do
    Map.delete(matching, {:value, removed_value})
    |> then(fn updated ->
      ## If variable is fixed, we'll update matching for it
      if MapSet.size(variable_domain) == 1 do
        fixed_value = MapSet.to_list(variable_domain) |> hd
        ## If there is a matching for already for the fixed value,
        ## we'll flip the edge for this matching
        fixed_value_vertex = {:value, fixed_value}
        updated_graph = case Map.get(matching, fixed_value_vertex) do
          nil -> value_graph
          variable_matching_vertex -> flip_edge(value_graph, variable_matching_vertex, fixed_value_vertex)
        end

        {updated_graph, Map.put(updated, {:value, fixed_value}, {:variable, var_id})}
      else
        {value_graph, updated}
      end
    end)
  end

  ## Find and run a reduction for the components that have unmatched variables
  # def update_components(vars, unmatched_variables, state) do
  #   update_components(vars, unmatched_variables, state, reduction_callback(vars))
  # end

  # def update_components(vars, unmatched_variables, %{components: components, matching: matching, value_graph: value_graph} = state, edge_removal_callback) do
  #   Enum.reduce(components, {unmatched_variables, [], matching, value_graph},
  #     fn %{variables: component_vars} = component, {unmatched_variables_acc, components_acc, matching_acc, value_graph_acc} = acc ->
  #       {unmatched_in_component, unmatched_variables_acc} =
  #         MapSet.split_with(unmatched_variables,
  #         fn unmatch -> unmatch in component_vars end)

  #       if MapSet.size(unmatched_in_component) == 0 do
  #         ## Nothing to do with this component, re-add
  #         {unmatched_variables_acc, [component | components_acc], matching_acc, value_graph_acc}
  #       else
  #         ## Reduce the component. This may produce the list of "split" components
  #         reduce(
  #         value_graph,
  #         matching,
  #         Enum.map(component_vars, fn var_id -> {:variable, var_id} end),
  #         edge_removal_callback
  #         )
  #       end
  #     end
  #   )
  # end

  def free_nodes(value_graph, variable_vertices) do
    Enum.reduce(variable_vertices, MapSet.new(), fn var_vertex, acc ->
      Enum.reduce(Graph.in_neighbors(value_graph, var_vertex), acc, fn val_vertex, acc2 ->
        ## No matching for the value => it's a free node
        (Graph.in_degree(value_graph, val_vertex) > 0 && acc2) ||
          MapSet.put(acc2, val_vertex)
      end)
    end)
  end

  def flip_matching(value_graph, matching) do
    Enum.reduce(matching, value_graph, fn {val, var}, g_acc ->
      flip_edge(g_acc, val, var)
      #
    end)
  end

  defp flip_edge(graph, v1, v2) do
    Graph.delete_edge(graph, v1, v2) |> Graph.add_edge(v2, v1)
  end

  ## Collect Γ(A) and A nodes by following paths starting from each variable
  ## the free node connected to
  def collect_GA_nodes(graph, free_node, acc) do
    Enum.reduce(Graph.out_neighbors(graph, free_node), acc, fn variable_vertex, acc2 ->
      if MapSet.member?(acc2, variable_vertex) do
        acc2
      else
        MapSet.union(acc2, alternating_path(graph, variable_vertex))
      end
    end)
  end

  def build_GA(value_graph, variable_vertices) do
    free_nodes = free_nodes(value_graph, variable_vertices)

    Enum.reduce(free_nodes, free_nodes, fn free_node, ga_set_acc ->
      collect_GA_nodes(value_graph, free_node, ga_set_acc)
    end)
  end

  ## Alternating path starting from (and including) vertex.
  ##
  def alternating_path(graph, vertex) do
    alternating_path(graph, vertex, MapSet.new([vertex]))
  end

  def alternating_path(graph, vertex, acc) do
    case Graph.out_neighbors(graph, vertex) do
      [] ->
        acc

      [next_in_path | _rest] ->
        (MapSet.member?(acc, next_in_path) && acc) ||
          alternating_path(graph, next_in_path, MapSet.put(acc, next_in_path))
    end
  end

  def remove_type1_edges(graph, ga_da_set, callback) do
    Enum.reduce(Graph.vertices(graph), {graph, MapSet.new()}, fn
      {:value, _value} = value_vertex, {graph_acc, complement_acc} = acc ->
        if MapSet.member?(ga_da_set, value_vertex) do
          acc
        else
          {graph_acc, MapSet.put(complement_acc, value_vertex)}
        end

      {:variable, var_idx} = variable_vertex, {graph_acc, complement_acc} ->
        if MapSet.member?(ga_da_set, variable_vertex) do
          ## Take all edges that are not in matching
          ## (the ones that are will be 'out' edges
          graph_acc =
            Enum.reduce(
              Graph.in_neighbors(graph_acc, variable_vertex),
              graph_acc,
              fn value_vertex, graph_acc2 ->
                if MapSet.member?(ga_da_set, {:value, value} = value_vertex) do
                  ## This value node is in Dc-A (as by the paper)
                  graph_acc2
                else
                  ## This value node is not in Dc-A, remove the edge
                  callback.(var_idx, value)
                  Graph.delete_edge(graph_acc2, value_vertex, variable_vertex)
                end
              end
            )

          {graph_acc, complement_acc}
        else
          {graph_acc, MapSet.put(complement_acc, variable_vertex)}
        end
    end)
  end

  def remove_type2_edges(value_graph, vertices, callback) do
    ## TODO: SCC detection without building a subgraph?
    type2_graph = Graph.subgraph(value_graph, vertices)
    sccs = Graph.strong_components(type2_graph)
    ## Make maps var_vertex => scc_id, val_vertex => scc_id
    vertex_to_scc_map =
      Enum.reduce(
        sccs,
        Map.new(),
        fn vertices, vertex_map_acc = _acc ->
          idx = make_ref()

          Enum.reduce(vertices, vertex_map_acc, fn
            vertex, vertex_map_acc2 ->
              Map.put(vertex_map_acc2, vertex, idx)
          end)
        end
      )

    ## Remove edges between SCCs
    value_graph =
      Enum.reduce(vertex_to_scc_map, value_graph, fn
        {{:value, _} = _vertex, _scc_id}, graph_acc ->
          graph_acc

        {{:variable, var_idx} = var_vertex, scc_id}, graph_acc ->
          Enum.reduce(Graph.in_neighbors(graph_acc, var_vertex), graph_acc, fn
            {:value, value} = value_vertex, graph_acc2 ->
              case Map.get(vertex_to_scc_map, value_vertex) do
                ## Not a cross-edge
                nil ->
                  graph_acc2

                value_scc when value_scc == scc_id ->
                  graph_acc2

                _different_scc ->
                  ## Cross-edge
                  callback.(var_idx, value)
                  Graph.delete_edge(graph_acc2, value_vertex, var_vertex)
              end
          end)
      end)

    {value_graph, sccs, vertex_to_scc_map}
  end

  ## Components with a single variable are "resolved" - they correspond to variables with the values
  ## that won't be shared with other variables.
  defp active_components_count(value_graph, matching, ga_da_set, sccs) do
    active_sccs_count = Enum.count(sccs, fn component -> length(component) > 2 end)
    active_sccs_count + (ga_da_set_active?(value_graph, matching, ga_da_set) && 1 || 0)

    # reduced_sccs =
    #   Enum.flat_map(sccs, fn component ->
    #     (length(component) > 2 && [component_record(component)]) || []
    #   end)

    # ga_da_components = Graph.subgraph(value_graph, ga_da_set) |> Graph.components()
    # Enum.reduce(ga_da_components, reduced_sccs, fn component, components_acc ->
    # ## meaning there is more than 1 variable in subgraph induced by ga_da_set.
    # (div(length(component), 2) > 1 &&
    # [component_record(component) | components_acc]) ||
    # components_acc
    # end)

  end

  def ga_da_set_active?(value_graph, matching, ga_da_set) do
    Enum.any?(matching, fn {value_vertex, _variable_vertex} ->
      # Are there value vertices that are connected to more than one variable vertex?
      value_vertex in ga_da_set
      && Graph.out_degree(value_graph, value_vertex) > 0
    end)
  end

end
