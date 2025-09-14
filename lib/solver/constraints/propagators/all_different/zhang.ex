defmodule CPSolver.Propagator.AllDifferent.Zhang do
  alias CPSolver.Propagator.AllDifferent.Utils, as: AllDiffUtils

  import CPSolver.Utils
  alias CPSolver.ValueGraph

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
        scheduled_for_removal: Map.new()
      },
      fn free_node, acc ->
        if visited?(acc, free_node) do
          acc
        else
          acc
          |> Map.put(:path_GA, MapSet.new())
          |> process_value_partition_node(free_node)
          |> then(fn %{path_GA: delta} = processed_state ->
            Map.update!(processed_state, :GA, fn ga ->
              single_vertex_component?(processed_state, delta) && ga ||
              MapSet.union(ga, delta) end)
          end)
        end
      end
    )
    |> remove_redundant_type1_edges()
    |> then(fn %{GA: ga} = state ->

      Map.put(state, :components,
        Enum.empty?(ga) && MapSet.new() || MapSet.new([state[:GA]]))
    end)
  end

  def process_value_partition_node(%{value_graph: graph} = state, node) do
    visited?(state, node) && state ||
      (
        state = mark_visited(state, node) |> unschedule_removals(node)
        neighbors = BitGraph.V.in_neighbors(graph, node)
        iterate(neighbors, state, fn left_partition_node, acc ->
          {:cont,
          (visited?(acc, left_partition_node) && acc) ||
            process_variable_partition_node(acc, left_partition_node)
          }
        end)
      )
  end

  def process_variable_partition_node(%{matching: matching} = state, _variable_vertex = node) do
    (visited?(state, node) && state) ||
      state
      |> mark_visited(node)
      |> Map.update!(:GA_complement_matching, fn nodes -> Map.delete(nodes, node) end)
      |> Map.update!(:path_GA, fn nodes -> MapSet.put(nodes, ValueGraph.variable_index(node)) end)
      |> process_value_partition_node(Map.get(matching, node))
      |> schedule_removals(node)
  end

  ### NOTE: components are sets of variable indices
  ### (not variable vertex indices!!!)
  ### TODO: consider changing for less confusion
  defp single_vertex_component?(%{value_graph: graph} = state, component) do
    cond do
      Enum.empty?(component) -> true
      MapSet.size(component) == 1 ->
        vertex = MapSet.to_list(component) |> hd
        Iter.Iterable.all?(BitGraph.out_neighbors(graph, vertex),
        fn value_node ->
          !visited?(state, value_node) &&
          BitGraph.degree(graph, value_node) == 1
        end)
      true -> false
    end

  end

  defp schedule_removals(
         %{free_nodes: free, value_graph: graph, scheduled_for_removal: scheduled} = state,
         node
       ) do
    BitGraph.V.out_neighbors(graph, node)
    |> iterate(scheduled, fn right_partition_node, unvisited_acc ->
      {:cont,
      ((visited?(state, right_partition_node) || MapSet.member?(free, right_partition_node)) &&
         unvisited_acc) ||
        Map.update(unvisited_acc, right_partition_node, MapSet.new([node]), fn existing ->
          MapSet.put(existing, node)
        end)
      }
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
      Enum.reduce(scheduled, graph, fn {right_partition_vertex_index, left_neighbors}, acc ->
        Enum.reduce(left_neighbors, acc, fn left_vertex, acc2 ->
          process_redundant_fun.(acc2, left_vertex, right_partition_vertex_index)
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
    AllDiffUtils.split_to_sccs(graph, Map.keys(matching), remove_edge_fun)
  end



end
