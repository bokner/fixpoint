defmodule CPSolver.Propagator.AllDifferent.Utils do
  alias CPSolver.ValueGraph
  alias CPSolver.Variable.Interface
  alias BitGraph.Neighbor, as: N

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
  ## Returns tuple {sccs, reduced_graph}
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
          {:variable, variable_id} = variable_vertex ->
            cross_neighbors = BitGraph.V.out_neighbors(graph_acc, vertex_index)
            {
              MapSet.put(vertices_acc, variable_id),
              remove_cross_edges(g_acc, variable_vertex, cross_neighbors, component, remove_edge_fun)
            }

          {:value, _} ->
            acc
          _ ->
            acc
        end
      end)

    ## drop 1-vertex sccs
    updated_components =
      MapSet.size(variable_vertices) > 1 && MapSet.put(component_acc, variable_vertices) || component_acc

    {updated_components, updated_graph}
  end

  defp remove_cross_edges(graph, variable_vertex, neighbors, component, remove_edge_fun) do
    N.iterate(neighbors, graph, fn neighbor, acc ->
          if neighbor in component do
            {:cont, acc}
          else
            {:cont, remove_edge_fun.(acc, variable_vertex, BitGraph.V.get_vertex(acc, neighbor))}
          end
    end)
  end


  def default_remove_edge_fun(vars) do
      fn graph, {:variable, var_index} = var_vertex, {:value, value} = value_vertex ->
        var = ValueGraph.get_variable(vars, var_index)
        if Interface.fixed?(var) do
          Interface.min(var) == value && graph || throw(:fail)
        else
          ValueGraph.delete_edge(graph, var_vertex, value_vertex, vars)
        end
    end
  end

end
