defmodule CPSolver.Propagator.AllDifferent.DC.Fast do
  @moduledoc """
  A Fast Algorithm for Generalized Arc Consistency of the Alldifferent Constraint
  Xizhe Zhang, Qian Li and Weixiong Zhang
  https://www.ijcai.org/proceedings/2018/0194.pdf
  """

  use CPSolver.Propagator

  alias CPSolver.ValueGraph
  alias CPSolver.Propagator.AllDifferent.Zhang
  alias CPSolver.Propagator.AllDifferent.Utils

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
    (
      state || initial_state(vars)
    )
    |> update_state(vars)
    |> apply_changes(changes)
    |> finalize()
  end

  def filter(vars) do
    filter(vars, nil, %{})
  end

  defp update_state(state, vars) do
    state
    |> Map.put(:propagator_variables, vars)
    |> Map.put(:reduction_callback, reduction_callback(vars))
  end

  defp finalize(state) do
    (entailed?(state) && :passive) ||
      {:state, cleanup_state(state)}
  end

  defp cleanup_state(state) do
    ## Do not use fixed matching other than for initial run
    Map.replace!(state, :fixed_matching, Map.new())
  end

  def entailed?(%{components: components} = _state) do
    Enum.empty?(components)
  end

  def entailed?(_state) do
    false
  end

  def initial_state(variables) do
    %{
      value_graph: value_graph,
      left_partition: variable_vertices,
      fixed_matching: fixed_matching,
      unfixed_indices: unfixed_indices,
      } = ValueGraph.build(variables, check_matching: true)

    %{
      value_graph: value_graph,
      variable_vertices: variable_vertices,
      fixed_matching: fixed_matching,
      unfixed_indices: unfixed_indices,
      ## We start with a single component wrapped in a set; normalize for compatibility with
      ## the shape of components (i.e., bare variable ids) produced by Zhang.
      components: MapSet.new(List.wrap(to_component(variable_vertices)))
    }
    |> update_state(variables)
  end

  defp reduction_callback(variables) do
    Utils.default_remove_edge_fun(variables)
  end

  def find_matching(value_graph, variable_vertices, fixed_matching \\ Map.new()) do
    try do
    BitGraph.Algorithms.bipartite_matching(
      value_graph,
      variable_vertices,
      fixed_matching: fixed_matching,
      required_size: MapSet.size(variable_vertices)
    )
    |> tap(fn matching -> matching || fail() end)
    catch {:error, _} ->
      fail()
    end
  end


  defp fail(reason \\ :fail) do
    throw(reason)
  end

  def reduce_state(state) do
    reduce_state(state, state.components)
  end

  def reduce_state(
        %{
          value_graph: value_graph,
          fixed_matching: fixed_matching,
          propagator_variables: variables,
          reduction_callback: remove_edge_fun
        } = state, component
      ) do
    %{free: free_nodes, matching: matching} =
      value_graph
      |> reset_value_graph(variables)
      |> find_matching(
        to_vertices(component),
        fixed_matching
        )

    %{value_graph: reduced_value_graph, components: new_components} =
      value_graph
      |> BitGraph.update_opts(neighbor_finder: ValueGraph.matching_neighbor_finder(value_graph, variables, matching, free_nodes))
      |> Zhang.reduce(free_nodes, matching, remove_edge_fun)

    state
    |> Map.put(:value_graph, reduced_value_graph)
    |> Map.update!(:components, fn components -> MapSet.union(components, new_components) end)
  end

  def apply_changes(%{components: components} = state, _changes) do
      Enum.reduce(components, state |> Map.put(:components, MapSet.new()), fn c, state_acc ->
        reduce_state(state_acc, c)
      end)
      # state
      # |> reset_value_graph()
      # |> reduce_state()
  end

  defp reset_value_graph(value_graph, vars) do
        BitGraph.update_opts(value_graph,
          neighbor_finder: ValueGraph.default_neighbor_finder(vars)
        )
  end


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

  ## The below is due to mismatch between BitGraph API
  ## and Zhang required shape for vertices.
  ## TODO: consider fixing
  defp to_component(variable_vertices) do
    MapSet.new(
        variable_vertices, fn {:variable, idx} -> idx end)
  end

  defp to_vertices(component) do
    MapSet.new(
        component, fn idx -> {:variable, idx} end)
  end


end
