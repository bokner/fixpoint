defmodule CPSolverTest.Algorithms.Kuhn do
  alias CPSolver.Algorithms.Kuhn
  use ExUnit.Case, async: false

  @three_vertices_instance [[1, 2], [1, 2], [1, 2, 3, 4]]
  @six_vertices_instance [
    [1, 4, 5],
    [9, 10],
    [1, 4, 5, 8, 9],
    [1, 4, 5],
    [1, 4, 5, 8, 9],
    [1, 4, 5]
  ]

  describe "Kuhn maximal matching" do
    test "3 vertices in left-side partition" do
      right_side_neighbors = @three_vertices_instance

      {bp_graph, left_partition} = build_bp_graph(right_side_neighbors)

      matching = Kuhn.run(bp_graph, left_partition)

      assert_matching(matching, 3)

      bp_graph2 = Graph.delete_edge(bp_graph, {:L, 3}, {:R, 3})

      matching2 = Kuhn.run(bp_graph2, left_partition)

      assert_matching(matching2, 3)

      bp_graph3 = Graph.delete_edge(bp_graph2, {:L, 3}, {:R, 4})

      ## 3 nodes in the left partition, 2 nodes in the right partition
      matching3 = Kuhn.run(bp_graph3, left_partition)

      assert_matching(matching3, 2)
    end

    test "6 vertices in left-side partition" do
      right_side_neighbors = @six_vertices_instance

      {bp_graph, left_partition} = build_bp_graph(right_side_neighbors)

      matching = Kuhn.run(bp_graph, left_partition)

      assert_matching(matching, 6)

      bp_graph2 = Graph.delete_edge(bp_graph, {:L, 6}, {:R, 5})

      matching2 = Kuhn.run(bp_graph2, left_partition)

      assert_matching(matching2, 6)

      bp_graph3 =
        bp_graph2
        |> Graph.delete_edge({:L, 1}, {:R, 5})
        |> Graph.delete_edge({:L, 4}, {:R, 5})

      matching3 = Kuhn.run(bp_graph3, left_partition)

      assert_matching(matching3, 5)
    end

    test "initial_matching (3 vertices)" do
      right_side_neighbors = @three_vertices_instance

      {bp_graph, left_partition} = build_bp_graph(right_side_neighbors)
      initial_matching = Kuhn.initial_matching(bp_graph, left_partition)

      assert_matching(Kuhn.run(bp_graph, left_partition, initial_matching), 3)
    end

    test "initial_matching (6 vertices)" do
      right_side_neighbors = @six_vertices_instance

      {bp_graph, left_partition} = build_bp_graph(right_side_neighbors)
      initial_matching = Kuhn.initial_matching(bp_graph, left_partition)

      assert_matching(Kuhn.run(bp_graph, left_partition, initial_matching), 6)
    end
  end

  defp build_bp_graph(right_side_neighbors) do
    left_partition = Enum.map(1..length(right_side_neighbors), fn idx -> {:L, idx} end)

    graph_input = Enum.zip(left_partition, right_side_neighbors)

    bp_graph =
      Enum.reduce(graph_input, Graph.new(), fn {ls_vertex, rs_neighbors}, g_acc ->
        edges = Enum.map(rs_neighbors, fn rsn -> {ls_vertex, {:R, rsn}} end)
        Graph.add_edges(g_acc, edges)
      end)

    {bp_graph, left_partition}
  end

  defp assert_matching(matching, size) do
    assert size == map_size(matching)
    assert size == Map.values(matching) |> Enum.uniq() |> length()
  end
end
