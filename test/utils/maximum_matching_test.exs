defmodule CPSolverTest.Utils.MaximumMatching do
  use ExUnit.Case

  describe "Maximum matching" do
    alias CPSolver.IntVariable, as: Variable
    alias CPSolver.Utils.MaximumMatching

    test "maxflow graph" do
      v1_values = 1..10
      v2_values = 1..10
      v3_values = 1..10
      domains = [v1_values, v2_values, v3_values]
      variables = Enum.map(domains, fn d -> Variable.new(d) end)
      network = MaximumMatching.build_flow_network(variables)

      ## Vertices are: source, sink, 3 variables and 10 values
      assert length(Graph.vertices(network)) == 2 + 3 + 10
      ## Edges from source to variables
      assert length(Graph.out_edges(network, :s)) == 3
      assert Enum.empty?(Graph.in_edges(network, :s))
      ## Edges from values to sink
      assert length(Graph.in_edges(network, :t)) == 10
      assert Enum.empty?(Graph.out_edges(network, :t))
      ## Edges from variables to values
      assert Enum.all?(
               Enum.with_index(domains),
               fn {domain, idx} ->
                 ## The only in-edge for vars is from :s
                 length(Graph.out_edges(network, {:variable, idx})) == 10 &&
                   length(Graph.in_edges(network, {:variable, idx})) == 1 &&
                   Enum.all?(domain, fn d ->
                    length(Graph.in_edges(network, {:value, d})) == 3 &&
                    length(Graph.out_edges(network, {:value, d})) == 1
                  end)
               end
             )
    end
  end
end
