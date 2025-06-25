defmodule CPSolver.Propagator.AllDifferent.DC.Fast do
  @moduledoc """
  A Fast Algorithm for Generalized Arc Consistency of the Alldifferent Constraint
  Xizhe Zhang, Qian Li and Weixiong Zhang
  https://www.ijcai.org/proceedings/2018/0194.pdf
  """

  use CPSolver.Propagator

  alias CPSolver.ValueGraph
  alias CPSolver.Propagator.AllDifferent.Zhang

  @impl true
  def reset(args, %{value_graph: _value_graph} = state) do
    state
    |> Map.put(:reduction_callback, build_reduction_callback(args))
  end

  def reset(_args, state) do
    state
  end

  @impl true
  def arguments(args) do
    Arrays.new(args, implementation: Aja.Vector)
  end

  @impl true
  def variables(args) do
    Enum.map(args, fn x_el -> set_propagate_on(x_el, :domain_change) end)
  end

  @impl true
  def filter(vars, state, changes) do
    ((state && apply_changes(Map.replace!(state, :propagator_variables, vars), changes)) ||
       initial_reduction(vars))
    |> finalize()
  end

  defp finalize(state) do
    (entailed?(state) && :passive) ||
      {:state, state}
  end

  def entailed?(%{components: components} = _state) do
    Enum.empty?(components)
  end

  def entailed?(_state) do
    false
  end

  def initial_reduction(vars) do
    initial_state = initial_state(vars)
    reduce_state(initial_state)
  end

  def initial_state(variables) do
    %{graph: value_graph, left_partition: variable_vertices, fixed: partial_matching} =
      ValueGraph.build(variables, check_matching: true)

    %{
      value_graph: value_graph,
      variable_vertices: variable_vertices,
      partial_matching: partial_matching,
      fixed_values: MapSet.new(partial_matching, fn {_var_vetex, {:value, value}} -> value end),
      propagator_variables: variables,
      reduction_callback: build_reduction_callback(variables)
    }
  end

  defp build_reduction_callback(variables) do
    fn graph, var_vertex, value_vertex ->
      ValueGraph.delete_edge(graph, get_variable_vertex(var_vertex), get_value_vertex(value_vertex), variables)
    end
  end

  def find_matching(value_graph, variable_vertices, partial_matching) do
    BitGraph.Algorithms.bipartite_matching(
      value_graph,
      variable_vertices,
      fixed_matching: partial_matching,
      required_size: MapSet.size(variable_vertices)
    )
    |> tap(fn matching -> matching || fail() end)
  end


  defp fail(reason \\ :fail) do
    throw(reason)
  end

  def reduce_state(
        %{
          value_graph: value_graph,
          partial_matching: partial_matching,
          variable_vertices: variable_vertices,
          propagator_variables: variables,
          reduction_callback: remove_edge_fun
        } = state
      ) do
    %{free: free_nodes, matching: matching} =
      value_graph
      |> find_matching(variable_vertices, partial_matching)

    %{value_graph: reduced_value_graph, components: components} =
      value_graph
      |> BitGraph.update_opts(neighbor_finder: ValueGraph.matching_neighbor_finder(value_graph, variables, matching))
      |> Zhang.reduce(free_nodes, matching, remove_edge_fun)

    state
    |> Map.put(:value_graph, reduced_value_graph)
    |> Map.put(:components, components)
    |> Map.put(:matching, matching)
  end

  def apply_changes(%{propagator_variables: vars} = _state, changes) when is_nil(changes) or map_size(changes) == 0 do
    initial_reduction(vars)
  end

  def apply_changes(%{value_graph: _value_graph, fixed_values: _fixed_values, propagator_variables: vars, partial_matching: _partial_matching} = _state, _changes) do
    initial_reduction(vars)
    # {new_fixed_values, new_partial_matching} = update_partial_matching(vars, partial_matching, fixed_values, changes)

    # state
    # |> Map.put(:value_graph,
    #   BitGraph.update_opts(value_graph,
    #     neighbor_finder: ValueGraph.default_neighbor_finder(vars)
    #   ))
    # |> Map.put(:partial_matching, new_partial_matching)
    # |> Map.put(:fixed_values, new_fixed_values)
    # |> reduce_state()
  end

  # defp update_partial_matching(variables, partial_matching, fixed_values, changes) do
  #   #{fixed_values, partial_matching}
  #   Enum.reduce(changes, {fixed_values, partial_matching},
  #     fn {var_index, :fixed}, {fixed_values_acc, partial_matching_acc} = acc ->
  #       var = get_variable(variables, var_index)
  #       fixed_value = min(var)
  #       case Map.get(partial_matching_acc, {:variable, var_index}) do
  #         nil ->
  #           ## New fixed variable
  #           ## Check if some other variable is fixed to the same value
  #           fixed_value in fixed_values_acc && fail()
  #           || {
  #             MapSet.put(fixed_values_acc, fixed_value),
  #             Map.put(partial_matching_acc, {:variable, var_index}, {:value, fixed_value})
  #             }
  #         {:value, value} ->
  #           value != fixed_value && fail(:fix_to_new_value) ## Fixed to new value? Should not ever happen, but we'll check
  #           || acc
  #       end

  #     _, acc -> acc
  #   end)
  # end

  defp build_component_locator(%{variable_vertices: variable_vertices} = state) do
    # Build an array with size equal to number of variables
    array_ref = :atomics.new(
      Enum.reduce(variable_vertices, 0, fn {:variable, var_index}, max_acc -> var_index > max_acc && var_index || max_acc end) + 1, signed: true)
    Enum.each(state.components, fn c -> build_component_locator_impl(array_ref, c) end)

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
  def get_component(%{component_locator: component_locator} = _state, var_index) do
    get_component(component_locator, var_index)
  end

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
