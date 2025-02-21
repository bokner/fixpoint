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

    def add_edge(bg, e, v1, v2, label) do
      BitGraph.add_edge(bg, e, v1, v2, label)
    end

    def add_vertex(bg, v) do
      BitGraph.add_vertex(bg, v)
    end

    def add_vertex(bg, v, label) do
      BitGraph.add_vertex(bg, v, label)
    end

    def delete_edge(bg, e) do
      BitGraph.del_edge(bg, e)
    end

    def delete_edges(bg, edges) do
      BitGraph.del_edges(bg, edges)
    end

    def delete_path(bg, v1, v2) do
      BitGraph.del_path(bg, v1, v2)
    end

    def delete_vertex(bg, v) do
      BitGraph.del_vertex(bg, v)
    end

    def delete_vertices(bg, vertices) do
      BitGraph.del_vertices(bg, vertices)
    end

    def delete(bg) do
      BitGraph.delete(bg)
    end

    def edge(bg, e) do
      BitGraph.edge(bg, e)
    end

    def edges(bg) do
      BitGraph.edges(bg)
      |> expand_edges(bg)
    end

    def edges(bg, v) do
      BitGraph.edges(bg, v)
      |> expand_edges(bg)
    end

    def get_cycle(bg, v) do
      BitGraph.get_cycle(bg, v)
    end

    def get_path(bg, v1, v2) do
      BitGraph.get_path(bg, v1, v2)
    end

    def get_short_cycle(bg, v) do
      BitGraph.get_short_cycle(bg, v)
    end

    def get_short_path(bg, v1, v2) do
      BitGraph.get_short_path(bg, v1, v2)
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

    defp expand_edges(edges, digraph) do
      Enum.map(edges, fn e ->
        {_edge_id, v1, v2, labels} = edge(digraph, e)
        %Graph.Edge{v1: v1, v2: v2, label: labels, weight: 1}
      end)
    end

end
