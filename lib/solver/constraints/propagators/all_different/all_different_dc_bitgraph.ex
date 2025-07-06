defmodule CPSolver.Propagator.AllDifferent.DC.BitGraph do
  use CPSolver.Propagator

  alias CPSolver.ValueGraph
  alias CPSolver.Propagator.AllDifferent.Utils, as: AllDiffUtils

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
  def filter(vars, state, changes) do
    state = (state && Map.put(state, :propagator_variables, vars)) || initial_state(vars)

    state
    |> apply_changes(changes)
    |> finalize()
  end

  defp finalize(state) do
    (entailed?(state) && :passive) ||
      {:state, state}
  end

  defp entailed?(%{sccs: sccs} = _state) do
    Enum.empty?(sccs)
  end

  defp apply_changes(
         %{
           sccs: sccs,
           propagator_variables: vars,
           value_graph: graph
         } = state,
         changes
       ) do
    if Enum.empty?(changes) do
      state
    else
      ## Apply changes to affected SCCs
      trigger_vars =
        Map.keys(changes) |> MapSet.new()

      sccs =
        Enum.reduce(sccs, [], fn %{component: component} = component_rec, sccs_acc ->
          component_triggers = MapSet.intersection(trigger_vars, component)

          if MapSet.size(component_triggers) == 0 do
            [component_rec | sccs_acc]
          else
            update_component(graph, vars, component_rec) ++ sccs_acc
          end
        end)

      Map.put(state, :sccs, sccs)
    end
  end

  defp update_component(
         value_graph,
         vars,
         %{component: component} = component_rec
       ) do
    ## We will mostly do what initial reduction does, but on a (lesser) subset of variables
    ## that is represented by a component.
    ## TODO:
    ## The difference is that we'll only run maximum matching
    ## if any of the trigger variables doesn't have the value associated with the matching edge.

    {_component_variable_map, repair_matching?} = component_variables(component_rec, vars)

    ## If matching hasn't changed, reuse;
    ## otherwise, start with partial matching built from fixed variables.
    matching = (repair_matching? && %{}) || component_rec[:matching]

    {_residual_graph, sccs} =
      reduction(
        vars,
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
      %{graph: value_graph, left_partition: variable_vertices, fixed_matching: fixed_matching} =
        ValueGraph.build(vars, check_matching: true)
    {_residual_graph, sccs} = reduction(vars, value_graph, variable_vertices, fixed_matching)

    %{
      propagator_variables: vars,
      sccs: sccs,
      value_graph: value_graph,
      variable_vertices: variable_vertices
    }
  end

  def reduction(vars, value_graph, variable_vertices, fixed_matching, repair_matching? \\ true) do
    matching =
      (repair_matching? &&
         compute_maximum_matching(value_graph, variable_vertices, fixed_matching)) ||
        fixed_matching

    {residual_graph, sccs} =
      build_residual_graph(value_graph, vars, matching)
      |> reduce_residual_graph(vars, matching.matching)

    {residual_graph, localize_state(sccs, value_graph, matching)}
  end

  def compute_maximum_matching(value_graph, variable_vertices, fixed_matching) do
    try do
    BitGraph.Algorithms.bipartite_matching(
      value_graph,
      variable_vertices,
      fixed_matching: fixed_matching,
      required_size: MapSet.size(variable_vertices)
    )
    |> tap(fn matching -> matching || fail() end)
    catch {:error, _} ->
      fail()
    end
  end

  def build_residual_graph(value_graph, variables, %{free: free_nodes, matching: matching}) do
    value_graph
    |> BitGraph.add_vertex(:sink)
    |> then(fn g ->
      BitGraph.update_opts(g,
        neighbor_finder: residual_graph_neighbor_finder(g, variables, free_nodes, matching)
      )
    end)
  end

  defp residual_graph_neighbor_finder(value_graph, variables, free_nodes, matching) do
    num_variables = Arrays.size(variables)
    base_neighbor_finder = ValueGraph.matching_neighbor_finder(value_graph, variables, matching)
    free_node_indices = Stream.map(free_nodes, fn value_vertex -> BitGraph.V.get_vertex_index(value_graph, value_vertex) end)
    matching_value_indices = Stream.map(Map.values(matching), fn value_vertex -> BitGraph.V.get_vertex_index(value_graph, value_vertex) end)
    sink_node_index = BitGraph.V.get_vertex_index(value_graph, :sink)

    fn graph, vertex_index, direction ->
      neighbors = base_neighbor_finder.(graph, vertex_index, direction)
      ## By construction of value graph, the variable vertices go first,
      ## followed by value vertices; the last on is 'sink' vertex
        cond do
          vertex_index == sink_node_index  && direction == :out->
            matching_value_indices
          vertex_index == sink_node_index  && direction == :in ->
            free_node_indices
          vertex_index <= num_variables ->
            neighbors
          direction == :in && vertex_index in free_node_indices ->
            neighbors
          direction == :out && vertex_index in free_node_indices ->
            MapSet.new([sink_node_index])
          direction == :in && vertex_index in matching_value_indices ->
            MapSet.put(neighbors, sink_node_index)
          direction == :out && vertex_index in matching_value_indices ->
            neighbors

        end

      end
  end

  def reduce_residual_graph(residual_graph, vars, matching) do
    AllDiffUtils.split_to_sccs(residual_graph, Map.keys(matching),
    AllDiffUtils.default_remove_edge_fun(vars))
  end

  ## Move parts of matching to where SCCs they belong to are
  defp localize_state(sccs, _value_graph, matching) do
    MapSet.new(sccs, fn component ->
      ## Component is a set of variable indices
      matching = Enum.reduce(component, Map.new(), fn c, m_acc ->
        var_vertex = {:variable, c}
        case Map.get(matching, var_vertex) do
          nil -> m_acc
          {:value, _value} = value_vertex ->
            Map.put(m_acc, var_vertex, value_vertex)
          end
        end)
        %{matching: matching, component: component}
      end)
    # ## Matching is value => var_id map
    # ## We want to reverse it, so we can do a lookup by var_id later on
    # matching_map =
    #   Enum.reduce(matching, Map.new(), fn {{:value, value}, {:variable, var_id}}, map_acc ->
    #     Map.put(map_acc, var_id, value)
    #   end)

    # ## Build records with list of variable ids and atached matching for SCCs
    # Enum.reduce(sccs, [], fn component, acc ->
    #   if MapSet.size(component) <= 1 do
    #     ## We don't have to handle components with less than 2 variables
    #     acc
    #   else
    #     {m, v_graph} =
    #       Enum.reduce(component, {Map.new(), Graph.new()}, fn var_id,
    #                                                           {matching_acc, value_graph_acc} =
    #                                                             acc ->
    #         case Map.get(matching_map, var_id) do
    #           nil ->
    #             acc

    #           value ->
    #             variable_vertex = {:variable, var_id}
    #             value_edges = Graph.in_edges(value_graph, variable_vertex)
    #             ## We keep matching in the original form so we can reuse it
    #             ## in in the consequent iterations
    #             {
    #               Map.put(matching_acc, {:value, value}, variable_vertex),
    #               Graph.add_edges(value_graph_acc, value_edges)
    #             }
    #         end
    #       end)

    #     [%{matching: m, component: component, value_graph: v_graph} | acc]
    #   end
    # end)
  end

  defp fail() do
    throw(:fail)
  end

end
