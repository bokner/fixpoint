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
      ## 4 variables and 5 values
      assert BitGraph.num_vertices(graph) == 9
    end

    test "default neighbor finder" do
      num_variables = 4
      domain = 1..5
      variables = Enum.map(1..num_variables, fn idx -> Variable.new(domain, name: "x#{idx}") end)
      %{graph: graph, left_partition: _left_partition} = ValueGraph.build(variables)
      neighbor_finder = ValueGraph.default_neighbor_finder(variables)
      ## For 'variable' vertices, all neighbors are 'out' vertices {:value, domain_value}.
      ## The domain of variable represented by 'variable' vertex is covered by it's neighbors.
      assert Enum.all?(0..(num_variables - 1), fn var_idx ->
               variable_vertex = {:variable, var_idx}

               BitGraph.out_neighbors(graph, variable_vertex, neighbor_finder: neighbor_finder) ==
                 MapSet.new(domain, fn val -> {:value, val} end) &&
                 Enum.empty?(
                   BitGraph.in_neighbors(graph, variable_vertex, neighbor_finder: neighbor_finder)
                 )
             end)

      ## For 'value' vertices, all neighbors are 'in' vertices {:variable, variable_index}
      ## The number of neighbors corresponds to the number of variables currently having the value
      ## in their domain
      assert Enum.all?(domain, fn value ->
               value_vertex = {:value, value}

               BitGraph.in_neighbors(graph, value_vertex, neighbor_finder: neighbor_finder) ==
                 MapSet.new(0..(num_variables - 1), fn var_index -> {:variable, var_index} end) &&
                 Enum.empty?(
                   BitGraph.out_neighbors(graph, value_vertex, neighbor_finder: neighbor_finder)
                 )
             end)

      ## Remove value from the domain of variable
      some_value = Enum.random(domain)
      some_variable_index = Enum.random(0..(num_variables - 1))
      Interface.remove(Enum.at(variables, some_variable_index), some_value)

      ## The 'value' vertex is removed from neighbors of the 'variable' vertex
      assert BitGraph.out_neighbors(graph, {:variable, some_variable_index},
               neighbor_finder: neighbor_finder
             ) ==
               MapSet.new(List.delete(Range.to_list(domain), some_value), fn val ->
                 {:value, val}
               end)

      # ... and vice versa
      assert BitGraph.in_neighbors(graph, {:value, some_value}, neighbor_finder: neighbor_finder) ==
               MapSet.new(
                 List.delete(Range.to_list(0..(num_variables - 1)), some_variable_index),
                 fn var -> {:variable, var} end
               )

      ## ... nothing changes otherwise
      assert Enum.empty?(
               BitGraph.out_neighbors(graph, {:value, some_value},
                 neighbor_finder: neighbor_finder
               )
             )

      assert Enum.empty?(
               BitGraph.in_neighbors(graph, {:variable, some_variable_index},
                 neighbor_finder: neighbor_finder
               )
             )
    end

    test "'matching' neighbor_finder" do
      domain = 1..5
      num_variables = 4

      variables = Enum.map(1..num_variables, fn idx -> Variable.new(domain, name: "x#{idx}") end)
      %{graph: graph, left_partition: left_partition} = ValueGraph.build(variables)
      assert %{matching: %{}} = BitGraph.Algorithms.bipartite_matching(graph, left_partition)

      matching =
        BitGraph.Algorithms.bipartite_matching(graph, left_partition,
          neighbor_finder: ValueGraph.default_neighbor_finder(variables)
        )

      assert MapSet.size(matching.free) == 1
      ## Matching is valid
      # 4 variables in the matching map
      assert map_size(matching.matching) == 4
      # 4 values in reverse matching map
      assert map_size(Map.new(matching.matching, fn {var, value} -> {value, var} end)) == 4

      ## Remove free node
      {:value, free_node_value} = free_vertex = MapSet.to_list(matching.free) |> hd()

      Enum.each(variables, fn v -> Interface.remove(v, free_node_value) end)

      ## Removal of values reflects in neighborhood
      ## , without expilicit removal of edges
      assert Enum.empty?(BitGraph.neighbors(graph, free_vertex))

      ## TODO: do it in ValueGraph
      graph = BitGraph.delete_vertex(graph, free_vertex)

      matching2 =
        BitGraph.Algorithms.bipartite_matching(graph, left_partition,
          neighbor_finder: ValueGraph.default_neighbor_finder(variables)
        )

      ## No free nodes
      assert Enum.empty?(matching2.free)
      ## Matching is valid
      # 4 variables in the matching map
      assert map_size(matching2.matching) == 4

      matching_neighbor_finder =
        ValueGraph.matching_neighbor_finder(graph, variables, matching2.matching)

      assert Enum.all?(matching2.matching, fn {var_vertex, value_vertex} ->
               BitGraph.out_neighbors(graph, value_vertex,
                 neighbor_finder: matching_neighbor_finder
               ) == MapSet.new([var_vertex]) &&
                 BitGraph.in_neighbors(graph, var_vertex,
                   neighbor_finder: matching_neighbor_finder
                 ) == MapSet.new([value_vertex]) &&
                 BitGraph.out_neighbors(graph, var_vertex,
                   neighbor_finder: matching_neighbor_finder
                 ) ==
                   Map.values(matching2.matching) |> MapSet.new() |> MapSet.delete(value_vertex) &&
                 BitGraph.in_neighbors(graph, value_vertex,
                   neighbor_finder: matching_neighbor_finder
                 ) ==
                   Map.keys(matching2.matching) |> MapSet.new() |> MapSet.delete(var_vertex)
             end)

      ## Original graph has edges from variables to values
      ## hence, not strongly connected
      refute BitGraph.strongly_connected?(graph)

      ## With matching edges oriented from values to variables,
      ## the graph becomes a cycle.
      matching_neighbor_finder =
        ValueGraph.matching_neighbor_finder(graph, variables, matching2.matching)

      assert BitGraph.strongly_connected?(graph,
               neighbor_finder: matching_neighbor_finder
             )

      ## Removing matching edge invalidates matching
      {{:variable, var_index} = var_vertex, {:value, matching_value} = value_vertex} =
        Enum.random(matching2.matching)

      refute :no_change == Interface.remove(Enum.at(variables, var_index), matching_value)

      ## Fails on invalid matching
      ## 1. Previously used neighbor finder
      assert catch_throw(BitGraph.strongly_connected?(graph,
                   neighbor_finder: matching_neighbor_finder
                 )) == {:invalid_matching, var_vertex, value_vertex}
      ## ...or the new one, with the same matching and variables
      assert catch_throw(BitGraph.strongly_connected?(graph,
                   neighbor_finder: ValueGraph.matching_neighbor_finder(graph, variables, matching2.matching)
                 )) == {:invalid_matching, var_vertex, value_vertex}


    end
  end
end
