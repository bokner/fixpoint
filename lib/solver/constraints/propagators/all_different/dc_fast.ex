defmodule CPSolver.Propagator.AllDifferent.DC.Zhang do
  @moduledoc """
  A Fast Algorithm for Generalized Arc Consistency of the Alldifferent Constraint
  Xizhe Zhang, Qian Li and Weixiong Zhang
  https://www.ijcai.org/proceedings/2018/0194.pdf
  """
  def remove_type1_edges(value_graph, matching, value_vertices) do
    ## Flip edges that are in matching
    graph = flip_matching(value_graph, matching)

    free_nodes = free_nodes(matching, value_vertices)
    ## Build set Γ(A) (neighbors of free value vertices)
    Enum.reduce(free_nodes, free_nodes, fn vertex, ga_set_acc ->
      ## Free node
      collect_GA_nodes(graph, vertex, ga_set_acc)
    end)
    |> remove_edges(graph)
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
    Enum.reduce(Graph.out_neighbors(graph, vertex), acc, fn variable_vertex, acc2 ->
      if MapSet.member?(acc2, variable_vertex) do
        acc2
      else
        MapSet.union(acc2, alternating_path(graph, variable_vertex))
      end
    end)
  end

  ## Alternating path starting from (and including) vertex.
  ## Alternating path always
  def alternating_path(graph, vertex) do
    alternating_path(graph, vertex, MapSet.new([vertex]))
  end

  def alternating_path(graph, vertex, acc) do
    case Graph.out_neighbors(graph, vertex) do
      [] ->
        acc

      [next_in_path] ->
        (MapSet.member?(acc, next_in_path) && acc) ||
          alternating_path(graph, next_in_path, MapSet.put(acc, next_in_path))
    end
  end

  def remove_edges(ga_da_set, graph) do
    Enum.reduce(ga_da_set, graph, fn
      {:value, _}, graph_acc ->
        graph_acc

      variable_vertex, graph_acc ->
        ## Take all edges that are not in matching
        ## (the ones that are will be 'out' edges
        Enum.reduce(Graph.in_neighbors(graph_acc, variable_vertex), graph_acc, fn value_vertex,
                                                                                  graph_acc2 ->
          if MapSet.member?(ga_da_set, value_vertex) do
            ## This value node is in Dc-A (as by the paper)
            graph_acc2
          else
            ## This value node is no in Dc-A, remove the edge
            Graph.delete_edge(graph_acc2, value_vertex, variable_vertex)
          end
        end)
    end)
  end
end
