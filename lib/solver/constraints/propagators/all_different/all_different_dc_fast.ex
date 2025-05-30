defmodule CPSolver.Propagator.AllDifferent.DC.Fast do
  @moduledoc """
  A Fast Algorithm for Generalized Arc Consistency of the Alldifferent Constraint
  Xizhe Zhang, Qian Li and Weixiong Zhang
  https://www.ijcai.org/proceedings/2018/0194.pdf
  """

  use CPSolver.Propagator

  alias BitGraph.Algorithms.Matching.Kuhn
  alias CPSolver.ValueGraph
  alias CPSolver.Propagator.AllDifferent.Zhang
  alias CPSolver.Utils

  @impl true
  def reset(_args, %{value_graph: value_graph} = state) do
    Map.put(state, :value_graph, BitGraph.copy(value_graph))
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
    ((state && apply_changes(vars, state, changes)) ||
       initial_reduction(vars))
    |> finalize()
  end

  defp finalize(state) do
    (entailed?(state) && :passive) ||
      {:state, state}
  end

  def entailed?(%{type1_components: type1, sccs: sccs} = state) do
    Enum.empty?(type1) && Enum.empty?(sccs)
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
      matching: partial_matching,
      reduction_callback: build_reduction_callback(variables),
      components: nil
    }
  end

  defp build_reduction_callback(variables) do
    fn graph, var_vertex, value_vertex ->
      remove(get_variable(variables, get_index(var_vertex)), get_index(value_vertex))
      BitGraph.delete_edge(graph, get_variable_vertex(var_vertex), get_value_vertex(value_vertex))
    end
  end

  def reduce_state(
        %{
          value_graph: value_graph,
          matching: partial_matching,
          variable_vertices: variable_vertices,
          reduction_callback: reduction_callback
        } = state
      ) do
    (value_graph_saturated?(value_graph, variable_vertices) && state) ||
      reduce_impl(
        value_graph,
        variable_vertices,
        partial_matching,
        reduction_callback
      )
  end

  def find_matching(value_graph, variable_vertices, partial_matching) do
    Kuhn.run(
      value_graph,
      variable_vertices,
      fixed_matching: partial_matching,
      required_size: MapSet.size(variable_vertices)
    )
    |> tap(fn matching -> matching || fail() end)
  end

  defp value_graph_saturated?(value_graph, variable_vertices) do
    num_vars = MapSet.size(variable_vertices)
    Enum.all?(variable_vertices, fn v -> BitGraph.out_degree(value_graph, v) >= num_vars end)
  end

  defp fail() do
    throw(:fail)
  end

  def reduce_impl(value_graph, variable_vertices, partial_matching, remove_edge_fun) do
    %{free: free_nodes, matching: matching} =
      find_matching(value_graph, variable_vertices, partial_matching)

    Zhang.reduce(value_graph, free_nodes, matching, remove_edge_fun)
  end

  def apply_changes(vars, _state, changes) when is_nil(changes) or map_size(changes) == 0 do
    initial_reduction(vars)
  end

  def apply_changes(vars, state, changes) do
    state =
      state
      |> Map.put(:component_locator, build_component_locator(state))
      |> Map.put(:propagator_variables, vars)

    Enum.reduce(changes, {state, changes}, fn {var_index, _domain_change} = _var_change,
                                              {state_acc, remaining_changes_acc} = acc ->
      (Map.has_key?(remaining_changes_acc, var_index) &&
         apply_variable_change(state_acc, var_index, remaining_changes_acc)) ||
        acc
    end)

    initial_reduction(vars)
  end

  defp apply_variable_change(state, variable_index, changes) do
    ## Get the component to apply the domain change to.
    ## Note: there is only one component to apply the triggered by a single variable change.
    ## There could be many variable changes applicable to a single component.
    ##
    ## - We get a component from a variable_index
    ## - retrieve applicable changes
    ## - apply them to a component (state, in general)
    ## - return updated state and reminder of changes to be used on a next
    ## reduction step
    case get_component(state, variable_index) do
      nil ->
        {state, changes}

      component ->
        {applicable_changes, remaining_changes} =
          Map.split_with(changes, fn {var_idx, _domain_change} -> var_idx in component end)

        {apply_changes_to_component(state, component, applicable_changes), remaining_changes}
    end
  end

  defp apply_changes_to_component(state, component, changes) do
    state
  end

  defp build_component_locator(%{matching: matching} = state) do
    # Build an array with size equal to number of variables
    num_variables = map_size(matching)
    array_ref = :atomics.new(num_variables, signed: true)
    Enum.each(state.type1_components, fn c -> build_component_locator_impl(array_ref, c) end)
    Enum.each(state.sccs, fn c -> build_component_locator_impl(array_ref, c) end)

    array_ref
  end

  def build_component_locator_impl(array_ref, component) do
    {first, last} =
      Enum.reduce(component, {nil, nil}, fn el, {first, prev} ->
        if first do
          :atomics.put(array_ref, prev, el + 1)
          {first, el + 1}
        else
          {el + 1, el + 1}
        end
      end)

    :atomics.put(array_ref, last, first)
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

  defp apply_variable_change(state, variable, variable_index, changes) do
    ## Get the component to apply the domain change to.
    ## Note: there is only one component to apply the triggered by a single variable change.
    ## There could be many variable changes applicable to a single component.
    ##
    ## - We get a component from a variable_index
    ## - retrieve applicable changes
    ## - apply them to a component (state, in general)
    ## - return updated state and reminder of changes to be used on a next
    ## reduction step
    case get_component(state, variable_index) do
      nil ->
        {state, changes}

      component ->
        {applicable_changes, remaining_changes} = Map.split(changes, component)
    end
  end

  defp matching_changed?(component, matching, vars, changes) do
    Enum.any?(changes, fn {var_index, domain_change} = change ->
      var_vertex = {:variable, var_index}

      var_vertex in component &&
        (
          var = get_variable(vars, var_index)

          fixed?(var) ||
            (
              {:value, matched_value} = Map.get(matching, var_vertex)
              !contains?(var, matched_value)
            )
        )
    end)
  end

  defp update_state(state, component, vars) do
    ## TODO
    state
  end

  defp reduce_sccs(state, type1_components, vars, changes) do
    state
  end

  defp reduce_component(graph, component) do
  end

  ## Helpers
  defp get_index({:variable, idx}) do
    idx
  end

  defp get_index({:value, idx}) do
    idx
  end

  defp get_index(idx) when is_integer(idx) do
    idx
  end

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

  defp get_variable(variables, var_index) do
    Propagator.arg_at(variables, var_index)
  end

  defp update_value_graph(graph, variables, {:variable, var_index} = variable_vertex) do
    var = get_variable(variables, var_index)
    [{:value, matched_value} = value_vertex] = BitGraph.in_neighbors(graph, variable_vertex)

    graph =
      (contains?(var, matched_value) && graph) ||
        BitGraph.delete_edge(graph, value_vertex, variable_vertex)

    Enum.reduce(
      BitGraph.out_neighbors(graph, variable_vertex),
      graph,
      fn {:value, value} = value_vertex, acc ->
        (contains?(var, value) && acc) || BitGraph.delete_edge(acc, variable_vertex, value_vertex)
      end
    )
  end
end
