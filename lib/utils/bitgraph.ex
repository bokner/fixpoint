defmodule CPSolver.Utils.BitGraph do
    def new(opts \\ []) do
      BitGraph.new(opts)
    end


    def add_edge(bg, v1, v2) do
      BitGraph.add_edge(bg, v1, v2)
    end

    def add_edge(bg, v1, v2, label) do
      BitGraph.add_edge(bg, v1, v2, label)
    end

    def add_vertex(bg, v) do
      BitGraph.add_vertex(bg, v)
    end

    def add_vertex(bg, v, label) do
      BitGraph.add_vertex(bg, v, label)
    end

    def delete_edge(bg, v1, v2) do
      BitGraph.delete_edge(bg, v1, v2)
    end

    def delete_edges(bg, edges) do
      Enum.reduce(edges, bg, fn {from, to} -> delete_edge(bg, from, to) end)
    end

    def delete_vertex(bg, v) do
      BitGraph.delete_vertex(bg, v)
    end

    def delete_vertices(bg, vertices) do
      Enum.reduce(vertices, bg, fn vertex -> delete_vertex(bg, vertex) end)
    end

    def edge(bg, v1, v2) do
      BitGraph.get_edge(bg, v1, v2)
    end

    def edges(bg) do
      BitGraph.edges(bg)
      |> expand_edges(bg)
    end

    def edges(bg, v) do
      BitGraph.edges(bg, v)
      |> expand_edges(bg)
    end

    def in_degree(bg, v) do
      BitGraph.in_degree(bg, v)
    end

    def in_edges(bg, v) do
      BitGraph.in_edges(bg, v)
      |> expand_edges(bg)
    end

    def in_neighbours(bg, v) do
      BitGraph.in_neighbors(bg, v)
    end

    def num_edges(bg) do
      BitGraph.num_edges(bg)
    end

    def num_vertices(bg) do
      BitGraph.num_vertices(bg)
    end

    def out_degree(bg, v) do
      BitGraph.out_degree(bg, v)
    end

    def out_edges(bg, v) do
      BitGraph.out_edges(bg, v)
      |> expand_edges(bg)
    end

    def out_neighbours(bg, v) do
      BitGraph.out_neighbors(bg, v)
    end

    def vertex(bg, v) do
      BitGraph.get_vertex(bg, v)
    end

    def vertices(bg) do
      BitGraph.vertices(bg)
    end

    def copy(graph) do
      BitGraph.copy(graph)
    end

    defp expand_edges(edges, graph) do
      Enum.map(edges, fn {v1, v2} ->
        {_edge_id, v1, v2, labels} = edge(graph, v1, v2)
        %Graph.Edge{v1: v1, v2: v2, label: labels, weight: 1}
      end)
    end

end
