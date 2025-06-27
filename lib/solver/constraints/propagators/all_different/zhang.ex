defmodule CPSolver.Propagator.AllDifferent.Zhang do
  def reduce(value_graph, free_nodes, matching, remove_edge_fun) do
    value_graph
    |> remove_type1_edges(free_nodes, matching, remove_edge_fun)
    |> remove_type2_edges(remove_edge_fun)
  end

  def remove_type1_edges(graph, free_nodes, matching, process_redundant_fun) do
    Enum.reduce(
      free_nodes,
      %{
        value_graph: graph,
        GA_complement_matching: matching,
        process_redundant_edges: process_redundant_fun,
        GA: MapSet.new(),
        visited: MapSet.new(),
        matching: matching,
        free_nodes: free_nodes,
        scheduled_for_removal: Map.new(),
        components: MapSet.new()
      },
      fn free_node, acc ->
        if visited?(acc, free_node) do
          acc
        else
          acc
          |> Map.put(:GA, MapSet.new())
          |> process_right_partition_node(free_node)
          |> then(fn %{GA: ga} = type1_state ->
            Map.update!(type1_state, :components,
            fn components -> (MapSet.size(ga) > 1) &&
              MapSet.put(components, ga) || components
            end)
          end)
        end
      end
    )
    |> remove_redundant_type1_edges()
  end

  def process_right_partition_node(%{value_graph: graph} = state, node) do
    (visited?(state, node) && state) ||
      (
        state = mark_visited(state, node) |> unschedule_removals(node)

        Enum.reduce(BitGraph.in_neighbors(graph, node), state, fn left_partition_node, acc ->
          (visited?(acc, left_partition_node) && acc) ||
            process_left_partition_node(acc, left_partition_node)
        end)
      )
  end

  def process_left_partition_node(%{matching: matching} = state, {:variable, variable_id} = node) do
    (visited?(state, node) && state) ||
      state
      |> mark_visited(node)
      |> Map.update!(:GA_complement_matching, fn nodes -> Map.delete(nodes, node) end)
      |> Map.update!(:GA, fn nodes -> MapSet.put(nodes, variable_id) end)
      |> process_right_partition_node(Map.get(matching, node))
      |> schedule_removals(node)
  end

  defp schedule_removals(
         %{free_nodes: free, value_graph: graph, scheduled_for_removal: scheduled} = state,
         node
       ) do
    BitGraph.out_neighbors(graph, node)
    |> Enum.reduce(scheduled, fn right_partition_node, unvisited_acc ->
      ((visited?(state, right_partition_node) || MapSet.member?(free, right_partition_node)) &&
         unvisited_acc) ||
        Map.update(unvisited_acc, right_partition_node, MapSet.new([node]), fn existing ->
          MapSet.put(existing, node)
        end)
    end)
    |> then(fn updated_schedule -> Map.put(state, :scheduled_for_removal, updated_schedule) end)
  end

  ## If right partition node has been visited, we unschedule all
  ## associated edges that were previously scheduled for removal.
  defp unschedule_removals(%{scheduled_for_removal: scheduled} = state, right_partition_node) do
    %{state | scheduled_for_removal: Map.delete(scheduled, right_partition_node)}
  end

  defp remove_redundant_type1_edges(
         %{
           value_graph: graph,
           scheduled_for_removal: scheduled,
           process_redundant_edges: process_redundant_fun
         } = state
       ) do
    updated_graph =
      Enum.reduce(scheduled, graph, fn {right_partition_vertex, left_neighbors}, acc ->
        Enum.reduce(left_neighbors, acc, fn left_vertex, acc2 ->
          process_redundant_fun.(acc2, left_vertex, right_partition_vertex)
        end)
      end)

    %{state | value_graph: updated_graph}
  end

  defp mark_visited(state, node) do
    Map.update!(state, :visited, fn visited -> MapSet.put(visited, node) end)
  end

  defp visited?(%{visited: visited} = _state, node) do
    MapSet.member?(visited, node)
  end

  def remove_type2_edges(%{value_graph: graph, GA_complement_matching: matching} = state, remove_edge_fun) do
    (Enum.empty?(matching) && state) ||
      graph
      |> process_sccs(matching, remove_edge_fun)
      |> then(fn {sccs, reduced_graph} ->
        state
        |> Map.put(:value_graph, reduced_graph)
        |> Map.update!(:components, fn components -> MapSet.union(sccs, components) end)
      end)
  end

  def process_sccs(graph, matching, remove_edge_fun) do
    BitGraph.Algorithms.strong_components(graph,
      vertices: Map.keys(matching),
      component_handler:
        {fn component, acc -> scc_component_handler(component, remove_edge_fun, acc) end,
         {MapSet.new(), graph}},
      algorithm: :tarjan
    )
  end

  def scc_component_handler(component, remove_edge_fun, {component_acc, graph_acc} = _current_acc) do
    {variable_vertices, updated_graph} =
      Enum.reduce(component, {MapSet.new(), graph_acc}, fn vertex_index,
                                                           {vertices_acc, g_acc} = acc ->
        case BitGraph.V.get_vertex(graph_acc, vertex_index) do
          ## We only need to remove out-edges from 'variable' vertices
          ## that cross to other SCCS
          {:variable, variable_id} = v ->
            foreign_neighbors = BitGraph.E.out_neighbors(g_acc, vertex_index)

            {
              MapSet.put(vertices_acc, variable_id),
              Enum.reduce(foreign_neighbors, g_acc, fn neighbor, g_acc2
                                                       when is_integer(neighbor) ->
                (neighbor in component && g_acc2) ||
                  remove_edge_fun.(g_acc2, v, BitGraph.V.get_vertex(g_acc2, neighbor))
              end)
            }

          {:value, _} ->
            acc
        end
      end)

    ## drop 1-vertex sccs
    updated_components =
      MapSet.size(variable_vertices) > 1 && MapSet.put(component_acc, variable_vertices) || component_acc

    {updated_components, updated_graph}
  end

end
