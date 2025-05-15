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
        visited: MapSet.new(),
        matching: matching
      },
      fn node, acc ->
        process_right_partition_node(acc, node)
      end
    )
    |> then(fn type1_state -> Map.put(type1_state, :components, type1_state.visited) end)
  end

  def process_right_partition_node(%{value_graph: graph} = state, node) do
    (visited?(state, node) && state) ||
      (
        # |> add_to_A(node)
        state = mark_visited(state, node)

        Enum.reduce(BitGraph.in_neighbors(graph, node), state, fn left_partition_node, acc ->
          (visited?(acc, left_partition_node) && acc) ||
            process_left_partition_node(state, left_partition_node)
        end)
      )
  end

  def process_left_partition_node(%{matching: matching} = state, node) do
    (visited?(state, node) && state) ||
      state
      |> mark_visited(node)
      |> Map.update!(:GA_complement_matching, fn nodes -> Map.delete(nodes, node) end)
      |> process_right_partition_node(Map.get(matching, node))
      |> process_redundant_edges(node)
  end

  defp process_redundant_edges(
         %{value_graph: graph, process_redundant_edges: process_redundant_fun} = state,
         node
       ) do
    BitGraph.out_neighbors(graph, node)
    |> Enum.reduce(graph, fn right_partition_node, g_acc ->
      (visited?(state, right_partition_node) && g_acc) ||
        process_redundant_fun.(g_acc, node, right_partition_node)
    end)
    |> then(fn g -> Map.put(state, :value_graph, g) end)
  end

  defp mark_visited(state, node) do
    Map.update!(state, :visited, fn visited -> MapSet.put(visited, node) end)
  end

  defp visited?(%{visited: visited} = _state, node) do
    MapSet.member?(visited, node)
  end

  def remove_type2_edges(%{GA_complement_matching: matching} = state, remove_edge_fun) do
    (Enum.empty?(matching) && state) ||
      state
      |> flip_matching_edges()
      |> process_sccs(matching, remove_edge_fun)
      |> then(fn {scc_components, reduced_graph} ->
        state
        |> Map.put(:value_graph, reduced_graph)
        |> Map.update!(:components, fn type1_component ->
          (MapSet.size(type1_component) > 0 && [type1_component | scc_components]) ||
            scc_components
        end)
      end)
  end

  defp flip_matching_edges(%{value_graph: graph, GA_complement_matching: matching} = _state) do
    Enum.reduce(matching, graph, fn {variable_vertex, value_vertex}, acc ->
      acc
      |> BitGraph.delete_edge(variable_vertex, value_vertex)
      |> BitGraph.add_edge(value_vertex, variable_vertex)
    end)
  end

  def process_sccs(graph, matching, remove_edge_fun) do
    BitGraph.Algorithms.strong_components(graph,
      vertices:
        Enum.reduce(matching, [], fn {var_vertex, value_vertex}, acc ->
          [var_vertex, value_vertex | acc]
        end),
      component_handler:
        {fn component, {component_acc, graph_acc} = _handler_acc ->
           Enum.reduce(component, {component_acc, graph_acc}, fn vertex_index,
                                                                 {c_acc, g_acc} = acc ->
             case BitGraph.V.get_vertex(graph_acc, vertex_index) do
               ## We only need to remove out-edges from 'variable' vertices
               ## that cross to other SCCS
               {:variable, _variable_id} = v ->
                 foreign_neighbors = BitGraph.E.out_neighbors(g_acc, vertex_index)

                 ## drop 1-vertex sccs
                 {(MapSet.size(component) > 1 && [component | c_acc]) || c_acc,
                  Enum.reduce(foreign_neighbors, g_acc, fn neighbor, g_acc2
                                                           when is_integer(neighbor) ->
                    (neighbor in component && g_acc2) ||
                      remove_edge_fun.(g_acc2, v, BitGraph.V.get_vertex(g_acc2, neighbor))
                  end)}

               {:value, _} ->
                 acc
             end
           end)
         end, {[], graph}},
      algorithm: :kozaraju
    )
  end
end
