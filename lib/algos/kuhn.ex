defmodule CPSolver.Algorithms.Kuhn do
  @moduledoc """
  Kuhn's algorithm to find maximum matching in bipartite graph.
  https://cp-algorithms.com/graph/kuhn_maximum_bipartite_matching.html
  """

  @doc """
  Given the bipartite graph, a list of vertices int the left partition,
  and (optional) partial matching %{right_side_vertex => left_side_vertex},
  find maximum matching
  """
  @spec run(Graph.t(), [any()], map()) :: map()
  def run(%Graph{} = graph, left_partition, fixed_matching \\ %{}, matching_size \\ nil) do
    partial_matching = Map.merge(initial_matching(graph, left_partition), fixed_matching)
    partition_size = length(left_partition)

    unmatched_limit =
      ((matching_size && matching_size - partition_size) || partition_size) -
        map_size(partial_matching)

    used = MapSet.new(Map.values(partial_matching))

    Enum.reduce_while(
      left_partition,
      {partial_matching, MapSet.new(), unmatched_limit},
      fn v, {matching_acc, visited_acc, unmatched_count} = acc ->
        if MapSet.member?(used, v) do
          {:cont, acc}
        else
          case augment(graph, v, matching_acc, visited_acc) do
            ## No augmenting path found for vertex v
            {false, _matching, updated_visited} ->
              ## If the required size of matching can not be reached, we fail early.
              case unmatched_count - 1 do
                new_unmatched_count when new_unmatched_count < 0 ->
                  {:halt, false}

                new_unmatched_count ->
                  {:cont, {matching_acc, updated_visited, new_unmatched_count}}
              end

            {true, increased_matching} ->
              {:cont, {increased_matching, MapSet.new(), unmatched_count}}
          end
        end
      end
    )
    |> then(fn
      false ->
        false

      {matching, _, _} ->
        if matching_size do
          map_size(matching) >= matching_size && matching
        else
          matching
        end
    end)
  end

  defp augment(graph, vertex, matching, visited_vertices) do
    if MapSet.member?(visited_vertices, vertex) do
      ## Skip already visited vertices
      {false, matching, visited_vertices}
    else
      ## Mark vertex from left partition as visited
      updated_visited = MapSet.put(visited_vertices, vertex)

      Enum.reduce_while(
        Graph.neighbors(graph, vertex),
        {false, matching, updated_visited},
        fn neighbor_vertex, {_path_found?, matching_acc, visited_acc} = acc ->
          case Map.get(matching_acc, neighbor_vertex) do
            nil ->
              {:halt, {true, Map.put(matching_acc, neighbor_vertex, vertex)}}

            match when match == vertex ->
              {:cont, acc}
            match ->
              case augment(
                     graph,
                     match,
                     matching_acc,
                     visited_acc
                   ) do
                {false, _matching, _visited} = path_not_found ->
                  {:cont, path_not_found}

                {true, new_matching} ->
                  {:halt, {true, Map.put(new_matching, neighbor_vertex, vertex)}}
              end
          end
        end
      )
    end
  end

  def initial_matching(graph, left_partition) do
    Enum.reduce(left_partition, Map.new(), fn ls_vertex, partial_matching ->
      Enum.reduce_while(
        Graph.neighbors(graph, ls_vertex),
        partial_matching,
        fn rs_vertex, matching_acc ->
          (Map.get(matching_acc, rs_vertex) && {:cont, matching_acc}) ||
            {:halt, Map.put(matching_acc, rs_vertex, ls_vertex)}
        end
      )
    end)
  end
end
