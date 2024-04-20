defmodule CPSolver.Algorithms.Kuhn do
  @moduledoc """
  Kuhn's algorithm to find maximum matching in bipartite graph.
  https://cp-algorithms.com/graph/kuhn_maximum_bipartite_matching.html
  """

  @doc """
  Given the bipartite graph, a list of it's left-part vertices,
  and (optional) initial matching %{right_side_vertex => left_side_vertex},
  find maximum matching
  """
  @spec run(Graph.t(), [any()], map()) :: map()
  def run(%Graph{} = graph, left_part_vertices, partial_matching \\ %{}) do
    Enum.reduce(left_part_vertices, {partial_matching, MapSet.new()}, fn v,
                                                                         {matching_acc,
                                                                          visited_acc} ->
      case augment(graph, v, matching_acc, visited_acc) do
        ## No augmented path found
        {false, _matching, updated_visited} -> {matching_acc, updated_visited}
        {true, increased_matching} -> {increased_matching, MapSet.new()}
      end
    end)
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
end
