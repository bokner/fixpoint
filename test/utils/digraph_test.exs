defmodule CPSolverTest.Utils.Digraph do
  use ExUnit.Case

  describe "Mutable digraph" do
    alias CPSolver.Utils.Digraph

    test "to/from libgraph" do
      libgraph =
        Graph.new()
        |> Graph.add_vertex(:d, label: :d_vertex) ## isolated vertex
        |> Graph.add_edge(:a, :b, label: :a_to_b)
        |> Graph.add_edge(:b, :a, label: :b_to_a)
        |> Graph.add_edge(:a, :c, label: :a_to_c)
        |> Graph.add_edge(:c, :a, label: :c_to_a)
        |> Graph.add_edge(:b, :c, label: :b_to_c)
        |> Graph.add_edge(:c, :b, label: :c_to_b)

        digraph = Digraph.from_libgraph(libgraph)

        ## Vertex and edges counts
        assert Graph.vertices(libgraph) |> Enum.sort() == Digraph.vertices(digraph) |> Enum.sort()
        assert length(Graph.edges(libgraph)) == length(Digraph.edges(digraph))

        ## Vertex labels
        assert Enum.all?(Graph.vertices(libgraph),
          fn vertex ->
            vertex_labels = Graph.vertex_labels(libgraph, vertex)
            {vertex, vertex_labels} == Digraph.vertex(digraph, vertex)
          end)

        ## Edge: vertices and labels
        assert Enum.all?(Digraph.edges(digraph),
        fn digraph_edge ->
          {_edge_id, v1, v2, labels}  = edge  = Digraph.edge(digraph, digraph_edge)
          libgraph_edge = Graph.edge(libgraph, v1, v2, labels)
          libgraph_edge.label == labels
        end)

       ## Digraph -> libgraph
       ## (libgraph -> digraph -> libgraph) transformation preserves the original graph
       libgraph2 = Digraph.to_libgraph(digraph)
       assert libgraph == libgraph2
    end
  end
end
