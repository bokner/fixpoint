defmodule CPSolver.Propagator.AllDifferent.DC.Zhang do
  def remove_type1_edges(value_graph, matching, value_vertices) do
    ## Flip edges that are in matching
    graph = flip_matching(value_graph, matching)

    free_nodes = free_nodes(matching, value_vertices)
    ## Build set Γ(A) (neighbors of free value vertices)
    Enum.reduce(free_nodes, MapSet.new(), fn vertex, ga_set_acc ->
        ## Free node
        collect_GA_nodes(graph, vertex, ga_set_acc)
    end)
  end

  def free_nodes(matching, value_vertices) do
    Enum.reduce(matching, value_vertices, fn {value_vertex, _var}, acc ->
      MapSet.delete(acc, value_vertex)
    end)
  end

  def flip_matching(value_graph, matching) do
    Enum.reduce(matching, value_graph, fn {val, var}, g_acc ->
      Graph.delete_edge(g_acc, val, var) |> Graph.add_edge(var, val)
    end)
  end

  def collect_GA_nodes(graph, vertex, acc) do
    Enum.reduce(Graph.out_neighbors(graph, vertex), acc, fn value_vertex, acc2 ->
      MapSet.union(acc2, alternating_path(graph, value_vertex))
    end)
  end

  def alternating_path(graph, vertex) do
    alternating_path(graph, vertex, MapSet.new([vertex]))
  end

  def alternating_path(graph, vertex, acc) do
    case Graph.out_neighbors(graph, vertex) do
      [] -> acc
      [next_in_path] -> alternating_path(graph, next_in_path, MapSet.put(acc, next_in_path))
    end
  end
end
