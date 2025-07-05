defmodule CPSolver.Propagator.AllDifferent.Utils do
  alias CPSolver.ValueGraph
  ## Splits graph into SCCs,
  ## and removes cross-edges.
  ## `vertices` is a subset of graph vertices
  ## that DFS will be run on.
  ## This means the split will be made on parts of the graph that
  ## are reachable from these vertices.
  ## `remove_edge_fun/3` is a function
  ## fn(graph, from_vertex, to_vertex)
  ## that returns (possibly modified) graph.
  ##
  def split_to_sccs(graph, vertices, remove_edge_fun \\ fn graph, from, to -> BitGraph.delete_edge(graph, from, to) end) do
    BitGraph.Algorithms.strong_components(graph,
      vertices: vertices,
      component_handler:
        {fn component, acc -> scc_component_handler(component, remove_edge_fun, acc) end,
         {MapSet.new(), graph}},
      algorithm: :tarjan
    )
  end

    def scc_component_handler(component, remove_edge_fun, {component_acc, graph_acc} = _current_acc) do
    {variable_vertices, updated_graph} =
      Enum.reduce(component, {MapSet.new(), graph_acc}, fn vertex_index,
                                                           {vertices_acc, g_acc} = acc ->
        case BitGraph.V.get_vertex(graph_acc, vertex_index) do
          ## We only need to remove out-edges from 'variable' vertices
          ## that cross to other SCCS
          {:variable, variable_id} = v ->
            foreign_neighbors = BitGraph.E.out_neighbors(g_acc, vertex_index)

            {
              MapSet.put(vertices_acc, variable_id),
              Enum.reduce(foreign_neighbors, g_acc, fn neighbor, g_acc2
                                                       when is_integer(neighbor) ->
                (neighbor in component && g_acc2) ||
                  remove_edge_fun.(g_acc2, v, BitGraph.V.get_vertex(g_acc2, neighbor))
              end)
            }

          {:value, _} ->
            acc
        end
      end)

    ## drop 1-vertex sccs
    updated_components =
      MapSet.size(variable_vertices) > 1 && MapSet.put(component_acc, variable_vertices) || component_acc

    {updated_components, updated_graph}
  end

  def default_remove_edge_fun(vars) do
      fn graph, var_vertex, value_vertex ->
      ValueGraph.delete_edge(graph, get_variable_vertex(var_vertex), get_value_vertex(value_vertex), vars)
      |> Map.get(:graph)
    end
  end

    ## Helpers
  defp get_variable_vertex({:variable, _vertex} = v) do
    v
  end

  defp get_variable_vertex(vertex) when is_integer(vertex) do
    {:variable, vertex}
  end

  defp get_value_vertex({:value, _vertex} = v) do
    v
  end

  defp get_value_vertex(vertex) when is_integer(vertex) do
    {:value, vertex}
  end

end
