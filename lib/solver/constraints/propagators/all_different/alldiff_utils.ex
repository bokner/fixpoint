defmodule CPSolver.Propagator.AllDifferent.Utils do
  alias CPSolver.ValueGraph
  alias CPSolver.Variable.Interface
  alias CPSolver.Propagator.Variable, as: PropagatorVariable
  alias CPSolver.Propagator
  alias BitGraph.Neighbor, as: N
  import CPSolver.Utils

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
  def split_to_sccs(
        graph,
        vertices,
        remove_edge_fun \\ fn graph, from, to -> BitGraph.delete_edge(graph, from, to) end
      ) do
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
      Enum.reduce(
        component,
        {MapSet.new(), graph_acc},
        fn vertex_index, {vertices_acc, g_acc} = acc ->
          case BitGraph.V.get_vertex(graph_acc, vertex_index) do
            ## We only need to remove out-edges from 'variable' vertices
            ## that cross to other SCCS
            {:variable, variable_id} = variable_vertex ->
              cross_neighbors = BitGraph.V.out_neighbors(graph_acc, vertex_index)

              {
                MapSet.put(vertices_acc, variable_id),
                remove_cross_edges(
                  g_acc,
                  variable_vertex,
                  cross_neighbors,
                  component,
                  remove_edge_fun
                )
              }

            {:value, _} ->
              acc

            _ ->
              acc
          end
        end
      )

    ## drop 1-vertex sccs
    updated_components =
      (MapSet.size(variable_vertices) > 1 && MapSet.put(component_acc, variable_vertices)) ||
        component_acc

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
        (Interface.min(var) == value && graph) || throw(:fail)
      else
        ValueGraph.delete_edge(graph, var_vertex, value_vertex, vars)
      end
    end
  end

  ## Forward checking (FWC)
  ## `unfixed_indices` is the list of indexes for yet (known) unfixed variables.
  ## We will be checking if they are really unfixed anyway.
  def forward_checking(variables) do
    forward_checking(variables, MapSet.new(0..(length(variables) - 1)), MapSet.new())
  end

  def forward_checking(variables, unfixed_indices, fixed_values) do
    case fwc_impl(variables, unfixed_indices, fixed_values) do
      {unfixed, fixed_values, true} ->
        forward_checking(variables, unfixed, fixed_values)

      {unfixed, fixed_values, false} ->
        {unfixed, fixed_values}
    end
  end

  def fwc_impl(variables, unfixed_indices, fixed_values) do
    iterate(
      unfixed_indices,
      {unfixed_indices, fixed_values, false},
      fn unfixed_idx,
         {u_acc, f_acc, _new_fixes?} =
           acc ->
        var = Propagator.arg_at(variables, unfixed_idx)
        {:cont,
         if PropagatorVariable.fixed?(var) do
           update_new_fixed(PropagatorVariable.min(var), unfixed_idx, u_acc, f_acc)
         else
           ## Go over all fixed values
           iterate(f_acc, acc, fn fixed_value, {u_acc2, f_acc2, _} = acc2 ->
             {:cont,
              if PropagatorVariable.remove(var, fixed_value) == :fixed do
                update_new_fixed(PropagatorVariable.min(var), unfixed_idx, u_acc2, f_acc2)
              else
                acc2
              end}
           end)
         end}
      end
    )
  end

  defp update_new_fixed(new_fixed_value, var_idx, current_unfixed, current_fixed) do
    if new_fixed_value in current_fixed, do: fail()
    {MapSet.delete(current_unfixed, var_idx), MapSet.put(current_fixed, new_fixed_value), true}
  end

  defp fail() do
    throw(:fail)
  end
end
