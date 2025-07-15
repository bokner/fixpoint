defmodule CPSolverTest.Utils.ValueGraph do
  use ExUnit.Case

  describe "Value Graph" do
    alias CPSolver.ValueGraph
    alias CPSolver.IntVariable, as: Variable
    alias CPSolver.Variable.Interface

    test "build" do
      num_variables = 4
      domain = 1..5
      variables = Enum.map(1..num_variables, fn idx -> Variable.new(domain, name: "x#{idx}") end)

      %{value_graph: graph, left_partition: _left_partition} = ValueGraph.build(variables)
      assert ValueGraph.get_variable_count(graph) == num_variables
      ## 4 variables and 5 values
      assert BitGraph.num_vertices(graph) == 9

      ## Ignore fixed variables
      variables = Enum.map([1, 1..2, [1, 2, 4, 5], 6], fn d -> Variable.new(d) end)
      %{value_graph: graph, left_partition: left_partition} = ValueGraph.build(variables,
      ignore_fixed_variables: true)

      assert {:variable, 1} in left_partition
      assert {:variable, 2} in left_partition
      # fixed variables are excluded
      refute {:variable, 0} in left_partition
      refute {:variable, 3} in left_partition
      # Value graph does not have fixed variables and fixed values not shared with other variables
      refute Enum.any?([{:variable, 0}, {:variable, 3}, {:value, 1}, {:value, 6}],
        fn vertex ->
          BitGraph.get_vertex(graph, vertex)
        end)
    end

    test "default neighbor finder" do
      num_variables = 4
      domain = 1..5
      variables = Enum.map(1..num_variables, fn idx -> Variable.new(domain, name: "x#{idx}") end)
      %{value_graph: graph, left_partition: _left_partition} = ValueGraph.build(variables)
      ## For 'variable' vertices, all neighbors are 'out' vertices {:value, domain_value}.
      ## The domain of variable represented by 'variable' vertex is covered by it's neighbors.
      assert Enum.all?(0..(num_variables - 1), fn var_idx ->
               variable_vertex = {:variable, var_idx}
               BitGraph.out_degree(graph, variable_vertex) == Range.size(domain) &&
               BitGraph.in_degree(graph, variable_vertex) == 0 &&
               BitGraph.out_neighbors(graph, variable_vertex) ==
                 MapSet.new(domain, fn val -> {:value, val} end) &&
                 Enum.empty?(
                   BitGraph.in_neighbors(graph, variable_vertex)
                 )
             end)

      ## For 'value' vertices, all neighbors are 'in' vertices {:variable, variable_index}
      ## The number of neighbors corresponds to the number of variables currently having the value
      ## in their domain
      assert Enum.all?(domain, fn value ->
               value_vertex = {:value, value}
               BitGraph.in_degree(graph, value_vertex) == num_variables &&
               BitGraph.out_degree(graph, value_vertex) == 0 &&

               BitGraph.in_neighbors(graph, value_vertex) ==
                 MapSet.new(0..(num_variables - 1), fn var_index -> {:variable, var_index} end) &&
                 Enum.empty?(
                   BitGraph.out_neighbors(graph, value_vertex)
                 )
             end)

      ## Remove value from the domain of variable
      some_value = Enum.random(domain)
      some_variable_index = Enum.random(0..(num_variables - 1))
      Interface.remove(Enum.at(variables, some_variable_index), some_value)

      ## The 'value' vertex is removed from neighbors of the 'variable' vertex
      assert BitGraph.out_neighbors(graph, {:variable, some_variable_index}) ==
               MapSet.new(List.delete(Range.to_list(domain), some_value), fn val ->
                 {:value, val}
               end)

      # ... and vice versa
      assert BitGraph.in_neighbors(graph, {:value, some_value}) ==
               MapSet.new(
                 List.delete(Range.to_list(0..(num_variables - 1)), some_variable_index),
                 fn var -> {:variable, var} end
               )

      ## ... nothing changes otherwise
      assert Enum.empty?(
               BitGraph.out_neighbors(graph, {:value, some_value})
             )

      assert Enum.empty?(
               BitGraph.in_neighbors(graph, {:variable, some_variable_index})
             )
    end

    test "'matching' neighbor_finder" do
      domain = 1..5
      num_variables = 4

      variables = Enum.map(1..num_variables, fn idx -> Variable.new(domain, name: "x#{idx}") end)
      %{value_graph: graph, left_partition: left_partition} = ValueGraph.build(variables)
      assert %{matching: %{}} = BitGraph.Algorithms.bipartite_matching(graph, left_partition)

      matching =
        BitGraph.Algorithms.bipartite_matching(graph, left_partition)

      assert MapSet.size(matching.free) == 1
      ## Matching is valid
      # 4 variables in the matching map
      assert map_size(matching.matching) == 4
      # 4 values in reverse matching map
      assert map_size(Map.new(matching.matching, fn {var, value} -> {value, var} end)) == 4

      ## Remove all edges to free node
      {:value, free_node_value} = free_vertex = MapSet.to_list(matching.free) |> hd()
      ## free node is in the graph before edge removals
      assert BitGraph.get_vertex(graph, free_vertex)

      graph = Enum.reduce(0..num_variables-1, graph, fn var_idx, graph_acc ->
        ValueGraph.delete_edge(graph_acc, {:variable, var_idx}, free_vertex, variables)
      end)

      ## Free node is no longer in the graph
      refute BitGraph.get_vertex(graph, free_vertex)

      ## Free node value is no longer in variable's domains
      refute Enum.any?(variables, fn var ->
        Interface.contains?(var, free_node_value)
      end)


      matching2 =
        BitGraph.Algorithms.bipartite_matching(graph, left_partition)

      ## No free nodes
      assert Enum.empty?(matching2.free)
      ## Matching is valid
      # 4 variables in the matching map
      assert map_size(matching2.matching) == 4

      matching_neighbor_finder =
        ValueGraph.matching_neighbor_finder(graph, variables, matching2.matching, matching2.free)

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
        ValueGraph.matching_neighbor_finder(graph, variables, matching2.matching, matching2.free)

      assert BitGraph.strongly_connected?(graph,
               neighbor_finder: matching_neighbor_finder
             )
    end

    test "matching neighbor finder with fixed variables" do
      domain = 1..3

      variables = Enum.map(domain, fn idx -> Variable.new(domain, name: "x#{idx}") end)
      %{value_graph: value_graph, left_partition: variable_vertices} = ValueGraph.build(variables)

      %{matching: matching, free: free_nodes}
        = BitGraph.Algorithms.bipartite_matching(value_graph, variable_vertices)

      var_index = 0
      ## Fix a variable...
      :fixed = Interface.fix(Enum.at(variables, var_index), 1)
      fixed_variable_vertex = {:variable, 0}
      matched_value_vertex = Map.get(matching, fixed_variable_vertex)
      reduced_matching = Map.delete(matching, fixed_variable_vertex)
      ## Create a 'matching' graph with reduced matching
      neighbor_finder =  ValueGraph.matching_neighbor_finder(value_graph, variables, reduced_matching, free_nodes)
      matching_graph = BitGraph.update_opts(value_graph, neighbor_finder: neighbor_finder)

      #IO.puts(ValueGraph.show_graph(value_graph, :value_grah))
      #IO.puts(ValueGraph.show_graph(matching_graph, :matching_graph))

      ## 'Variable' vertices that are not part of (reduced) matching are isolated
      assert BitGraph.degree(matching_graph, fixed_variable_vertex) == 0
      ## The values for excluded matches are isolated.
      assert BitGraph.degree(matching_graph, matched_value_vertex) == 0
      refute fixed_variable_vertex in BitGraph.in_neighbors(matching_graph, matched_value_vertex)
      ## The variables in the matching do not have matched value vertex as a neighbor
      refute Enum.any?(reduced_matching, fn {var_vertex, _value_vertex} ->
        matched_value_vertex in (BitGraph.neighbors(matching_graph, var_vertex))
      end)


    end

    test "forward checking" do
      domains = [
        1, [2, 3, 5], [1, 4], [1, 5]
      ]
      [x0, x1, x2, x3] = variables = Enum.map(domains, fn d -> Variable.new(d) end)
      %{value_graph: graph} = ValueGraph.build(variables)

      assert BitGraph.num_vertices(graph) == 9

      %{value_graph: updated_graph, new_fixed: new_fixed} =
        ValueGraph.forward_checking(graph, MapSet.new([{:variable, 0}]), variables)

      ## Newly fixed variables
      assert new_fixed == MapSet.new([{:variable, 2}, {:variable, 3}])

      ## Domain reductions
      assert CPSolver.Utils.domain_values(x1) == MapSet.new([2, 3])
      assert Interface.fixed?(x0) && Interface.min(x0) == 1
      assert Interface.fixed?(x2) && Interface.min(x2) == 4
      assert Interface.fixed?(x3) && Interface.min(x3) == 5

      ## Value graph does not have fixed variables and associated values
      assert BitGraph.vertices(updated_graph) == MapSet.new([{:variable, 1}, {:value, 2}, {:value, 3}])
    end
  end
end
