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
    if state do
      update_state(state, vars)
    else
     initial_state(vars)
    end
    |> apply_changes(changes)
    |> finalize()
  end

  defp update_state(state, vars) do
    state
    |> Map.put(:propagator_variables, vars)
    |> Map.put(:reduction_callback, reduction_callback(vars))
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
      components: MapSet.new(variable_vertices) ## We start with a single component wrapped in a set
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

  def reduce_state(
        %{
          value_graph: value_graph,
          variable_vertices: variable_vertices,
          unfixed_indices: unfixed_indices,
          fixed_matching: fixed_matching,
          propagator_variables: variables,
          reduction_callback: remove_edge_fun
        } = state
      ) do
        # if 0 != MapSet.size(unfixed_indices) do
        #   IO.inspect(Map.take(state, [:unfixed_indices]), label: :reduce_state)
        # end
    %{free: free_nodes, matching: matching} =
      value_graph
      |> find_matching(
        #MapSet.new(unfixed_indices, fn idx -> {:variable, idx} end),
        variable_vertices,
        fixed_matching
        #Map.new()
        )

    %{value_graph: reduced_value_graph, components: components} =
      value_graph
      |> BitGraph.update_opts(neighbor_finder: ValueGraph.matching_neighbor_finder(value_graph, variables, matching, free_nodes))
      |> Zhang.reduce(free_nodes, matching, remove_edge_fun)

    state
    |> Map.put(:value_graph, reduced_value_graph)
    |> Map.put(:components, components)
  end

  def apply_changes(%{components: components} = state, changes) do
      #Enum.reduce(components, state, fn c, acc ->

      #end)
      state
      |> reset_value_graph()
      |> reduce_state()
  end

  defp reset_value_graph(%{value_graph: value_graph,
    propagator_variables: vars
    } = state) do
    state
    |> Map.put(:value_graph,
        BitGraph.update_opts(value_graph,
          neighbor_finder: ValueGraph.default_neighbor_finder(vars)
        )
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


end
