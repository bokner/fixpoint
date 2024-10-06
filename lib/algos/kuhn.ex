defmodule CPSolver.Algorithms.Kuhn do
  @moduledoc """
  Kuhn's algorithm to find maximum matching in bipartite graph.
  https://cp-algorithms.com/graph/kuhn_maximum_bipartite_matching.html
  """

  @doc """
  Given the bipartite graph, a list of vertices int the left partition,
  and (optional) initial matching %{right_side_vertex => left_side_vertex},
  find maximum matching
  """
  @spec run(Graph.t(), [any()], map()) :: map()
  def run(%Graph{} = graph, left_partition, partial_matching \\ %{}) do
    used = MapSet.new(Map.values(partial_matching))

    Enum.reduce(
      left_partition,
      {partial_matching, MapSet.new()},
      fn v, {matching_acc, visited_acc} = acc ->
        if MapSet.member?(used, v) do
          acc
        else
          case augment(graph, v, matching_acc, visited_acc) do
            ## No augmented path found
            {false, _matching, updated_visited} -> {matching_acc, updated_visited}
            {true, increased_matching} -> {increased_matching, MapSet.new()}
          end
        end
      end
    )
    |> elem(0)
  end

  defp augment(graph, ls_vertex, matching, visited_vertices) do
    if MapSet.member?(visited_vertices, ls_vertex) do
      {false, matching, visited_vertices}
    else
      updated_visited = MapSet.put(visited_vertices, ls_vertex)

      Enum.reduce_while(
        Graph.neighbors(graph, ls_vertex),
        {false, matching, updated_visited},
        fn rs_vertex, {_found?, matching_acc, visited_acc} ->
          case Map.get(matching_acc, rs_vertex) do
            nil ->
              {:halt, {true, Map.put(matching_acc, rs_vertex, ls_vertex)}}

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
                  {:halt, {true, Map.put(new_matching, rs_vertex, ls_vertex)}}
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
