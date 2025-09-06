defmodule CPSolver.Propagator.AllDifferent.Utils do
  alias CPSolver.ValueGraph
  alias CPSolver.Variable.Interface
  alias CPSolver.Propagator.Variable, as: PropagatorVariable
  alias CPSolver.Propagator
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
    BitGraph.Algorithm.strong_components(graph,
      vertices: vertices,
      component_handler:
        {fn component, acc -> scc_component_handler(component, remove_edge_fun, acc) end,
         {MapSet.new(), graph}},
      algorithm: :tarjan
    )
  end

  def scc_component_handler(component, remove_edge_fun, {component_acc, graph_acc} = _current_acc) do
    {variable_vertices, updated_graph} =
      Enum.reduce(component, {MapSet.new(), graph_acc},
        fn vertex_index, {vertices_acc, g_acc} = acc ->
          cond do
            ValueGraph.vertex_type(g_acc, vertex_index) == :variable ->
            ## We only need to remove out-edges from 'variable' vertices
            ## that cross to other SCCS
              cross_neighbors = BitGraph.V.out_neighbors(graph_acc, vertex_index)
              variable_id = vertex_index - 1
              {
                MapSet.put(vertices_acc, variable_id),
                remove_cross_edges(
                  g_acc,
                  vertex_index,
                  cross_neighbors,
                  component,
                  remove_edge_fun
                )
              }

            true ->
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

  defp remove_cross_edges(graph, variable_vertex_index, neighbors, component, remove_edge_fun) do
    ## Note: neighbors of 'variable' vertex are 'value' vertices
    iterate(neighbors, graph, fn neighbor, acc ->
      if neighbor in component do
        {:cont, acc}
      else
        {:cont, remove_edge_fun.(acc, variable_vertex_index, ValueGraph.get_value(graph, neighbor))}
      end
    end)
  end

  def default_remove_edge_fun(vars) do
    fn graph, var_vertex_index, value ->
      var_index = var_vertex_index - 1
      var = ValueGraph.get_variable(vars, var_index)

      if Interface.fixed?(var) do
        (Interface.min(var) == value && graph) || throw(:fail)
      else
        ValueGraph.delete_edge(graph, var_index, value, vars)
      end
    end
  end

  ## Forward checking (FWC)
  ## `unfixed_indices` is the list of indexes for yet (known) unfixed variables.
  ## We will be checking if they are really unfixed anyway.
  def forward_checking(variables) do
    forward_checking(variables,
      MapSet.new(0..(Propagator.arg_size(variables) - 1)),
      MapSet.new())
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

  #### Component locator.
  ### This is the structure to (quickly) locate the component the verex belongs to.
  ### Given the list of disjoint sets (of vertices), and an element (vertex):
  ### what set (component) the element (vertex) belongs to?
  ### Motivation: to be able to pick out components for the reduction, based on domain changes.
  ### That is, if we get the {0, domain_change}, what component is to process?
  ###
  def build_component_locator(vertices, components) do
    # Build an array with size equal to number of variables
    array_ref = :atomics.new(
      Enum.reduce(vertices, 0, fn index, max_acc -> index > max_acc && index || max_acc end) + 1, signed: true)
    Enum.each(components, fn c -> build_component_locator_impl(array_ref, c) end)

    array_ref
  end

  ## Mind 1-based (indices in component finder) vs. 0-based (variable indices in the component)
  ##
  def build_component_locator_impl(component_finder, component) do
    {first, last} =
      Enum.reduce(component, {nil, nil}, fn el, {first, prev} ->
        if first do
          :atomics.put(component_finder, prev, el + 1)
          {first, el + 1}
        else
          {el + 1, el + 1}
        end
      end)

    :atomics.put(component_finder, last, first)
  end

  ## Retrieve component vertices the variable given by it's idex
  ## belongs to.
  def get_component(component_locator, var_index) do
    base1_index = var_index + 1

    if :atomics.info(component_locator)[:size] < base1_index do
      nil
    else
      case :atomics.get(component_locator, base1_index) do
        0 ->
          nil

        next ->
          get_component_impl(
            component_locator,
            base1_index,
            next,
            MapSet.new([var_index, next - 1])
          )
      end
    end
  end

  defp get_component_impl(component_locator, first_index, current_index, acc) do
    next_index = :atomics.get(component_locator, current_index)

    (next_index == first_index && acc) ||
      get_component_impl(
        component_locator,
        first_index,
        next_index,
        MapSet.put(acc, next_index - 1)
      )
  end


  defp fail() do
    throw(:fail)
  end
end
