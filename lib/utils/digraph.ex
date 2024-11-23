defmodule CPSolver.Digraph do
    def new(opts \\ []) do
      :digraph.new(opts)
    end


    def add_edge(dg, v1, v2) do
      :digraph.add_edge(dg, v1, v2)
      dg
    end

    def add_edge(dg, v1, v2, label) do
      :digraph.add_edge(dg, v1, v2, label)
      dg
    end

    def add_edge(dg, e, v1, v2, label) do
      :digraph.add_edge(dg, e, v1, v2, label)
      dg
    end

    def add_vertex(dg, v) do
      :digraph.add_vertex(dg, v)
      dg
    end

    def add_vertex(dg, v, label) do
      :digraph.add_vertex(dg, v, label)
      dg
    end

    def delete_edge(dg, e) do
      :digraph.del_edge(dg, e)
      dg
    end

    def delete_edges(dg, edges) do
      :digraph.del_edges(dg, edges)
      dg
    end

    def delete_path(dg, v1, v2) do
      :digraph.del_path(dg, v1, v2)
      dg
    end

    def delete_vertex(dg, v) do
      :digraph.del_vertex(dg, v)
      dg
    end

    def delete_vertices(dg, vertices) do
      :digraph.del_vertices(dg, vertices)
      dg
    end

    def delete(dg) do
      :digraph.delete(dg)
    end

    def edge(dg, e) do
      :digraph.edge(dg, e)
    end

    def edges(dg) do
      :digraph.edges(dg)
    end

    def edges(dg, v) do
      :digraph.edges(dg, v)
    end

    def get_cycle(dg, v) do
      :digraph.get_cycle(dg, v)
    end

    def get_path(dg, v1, v2) do
      :digraph.get_path(dg, v1, v2)
    end

    def get_short_cycle(dg, v) do
      :digraph.get_short_cycle(dg, v)
    end

    def get_short_path(dg, v1, v2) do
      :digraph.get_short_path(dg, v1, v2)
    end

    def in_degree(dg, v) do
      :digraph.in_degree(dg, v)
    end

    def in_edges(dg, v) do
      :digraph.in_edges(dg, v)
    end

    def in_neighbours(dg, v) do
      :digraph.in_neighbours(dg, v)
    end

    def no_edges(dg) do
      :digraph.no_edges(dg)
    end

    def no_vertices(dg) do
      :digraph.no_vertices(dg)
    end

    def out_degree(dg, v) do
      :digraph.out_degree(dg, v)
    end

    def out_edges(dg, v) do
      :digraph.out_edges(dg, v)
    end

    def out_neighbours(dg, v) do
      :digraph.out_neighbours(dg, v)
    end

    def vertex(dg, v) do
      :digraph.vertex(dg, v)
    end

    def vertices(dg) do
      :digraph.vertices(dg)
    end

    def from_libgraph(%Graph{} = graph) do

    end

    def to_libgraph(digraph) do

    end

end
