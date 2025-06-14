defmodule CPSolverTest.Utils.ValueGraph do
  use ExUnit.Case

  describe "Value Graph" do
    alias CPSolver.ValueGraph
    alias CPSolver.IntVariable, as: Variable
    alias CPSolver.Variable.Interface

    test "build" do
      variables = Enum.map(1..4, fn idx -> Variable.new(1..5, name: "x#{idx}") end)
      %{graph: graph, left_partition: left_partition} = ValueGraph.build(variables)
      assert MapSet.size(left_partition) == length(variables)
      assert BitGraph.num_vertices(graph) == 9 ## 4 variables and 5 values
    end

    test "edges with neighbor_finder" do
      variables = Enum.map(1..4, fn idx -> Variable.new(1..5, name: "x#{idx}") end)
      %{graph: graph, left_partition: left_partition} = ValueGraph.build(variables)
      assert %{matching: %{}} = BitGraph.Algorithms.bipartite_matching(graph, left_partition)
      matching = BitGraph.Algorithms.bipartite_matching(graph, left_partition,
        neighbor_finder: ValueGraph.default_neighbor_finder(variables))
      assert MapSet.size(matching.free) == 1
      ## Matching is valid
      # 4 variables in the matching map
      assert map_size(matching.matching) == 4
      # 4 values in reverse matching map
      assert map_size(Map.new(matching.matching, fn {var, value} -> {value, var} end)) == 4

      ## Remove free node
      {:value, free_node_value} = free_vertex = MapSet.to_list(matching.free) |> hd()

      Enum.each(variables, fn v -> Interface.remove(v, free_node_value) end)
      ## TODO: do it in ValueGraph
      graph = BitGraph.delete_vertex(graph, free_vertex)

      matching2 = BitGraph.Algorithms.bipartite_matching(graph, left_partition,
        neighbor_finder: ValueGraph.default_neighbor_finder(variables))

      ## No free nodes
      assert MapSet.size(matching2.free) == 0
      ## Matching is valid
      # 4 variables in the matching map
      assert map_size(matching2.matching) == 4

      refute BitGraph.strongly_connected?(graph)

    end
  end
end
