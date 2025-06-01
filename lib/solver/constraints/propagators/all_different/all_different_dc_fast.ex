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
  def reset(args, %{value_graph: value_graph} = state) do
    state
    |> Map.put(:value_graph, BitGraph.copy(value_graph))
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
    ((state && apply_changes(vars, state, changes)) ||
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
      matching: partial_matching,
      propagator_variables: variables,
      reduction_callback: build_reduction_callback(variables)
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
          variable_vertices: variable_vertices
        } = state
      ) do
    (value_graph_saturated?(value_graph, variable_vertices) && state) ||
      reduce_impl(state)
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

  def reduce_impl(
        %{
          value_graph: value_graph,
          matching: partial_matching,
          variable_vertices: variable_vertices,
          reduction_callback: remove_edge_fun
        } = state
      ) do
    %{free: free_nodes, matching: matching} =
      find_matching(value_graph, variable_vertices, partial_matching)

    %{value_graph: reduced_value_graph, components: components} =
      Zhang.reduce(value_graph, free_nodes, matching, remove_edge_fun)

    state
    |> Map.put(:value_graph, reduced_value_graph)
    |> Map.put(:components, components)
    |> Map.put(:matching, matching)
  end

  def apply_changes(vars, _state, changes) when is_nil(changes) or map_size(changes) == 0 do
    initial_reduction(vars)
  end

  def apply_changes(vars, state, changes) do
    # state =
    #   state
    #   |> Map.put(:component_locator, build_component_locator(state))
    #   |> Map.put(:propagator_variables, vars)

    # {updated_state, _} =
    #   Enum.reduce(changes, {state, changes}, fn {var_index, _domain_change} = _var_change,
    #                                             {state_acc, remaining_changes_acc} = acc ->
    #     (Map.has_key?(remaining_changes_acc, var_index) &&
    #        apply_variable_change(state_acc, var_index, remaining_changes_acc)) ||
    #       acc
    #   end)

    ## TODO: remove
    initial_reduction(vars)
  end

  defp apply_variable_change(
         %{component_locator: component_locator} = state,
         variable_index,
         changes
       ) do
    ## Get the component to apply the domain change to.
    ## Note: there is only one component to apply the triggered by a single variable change.
    ## There could be many variable changes applicable to a single component.
    ##
    ## - We get a component from a variable_index
    ## - retrieve applicable changes
    ## - apply them to a component (state, in general)
    ## - return updated state and rest of changes to be used on a next
    ## reduction step
    case get_component(component_locator, variable_index) do
      nil ->
        {state, changes}

      component ->
        {applicable_changes, remaining_changes} =
          Map.split_with(changes, fn {var_idx, _domain_change} -> var_idx in component end)

        {reduce_component(state, component, applicable_changes), remaining_changes}
    end
  end

  defp reduce_component(
         %{matching: matching, propagator_variables: vars} = state,
         component,
         changes
       ) do
    {updated_state, matching_changed?} =
      Enum.reduce(changes, {state, false}, fn {var_index, domain_change},
                                              {state_acc, change_flag_acc} ->
        (matching_changed?(matching, vars, var_index, domain_change) &&
           {state_acc, true}) ||
          {
            Map.update!(state_acc, :value_graph, fn value_graph ->
              update_value_graph(value_graph, vars, var_index)
            end),
            change_flag_acc || false
          }
      end)

    (matching_changed? && reduce_component_zhang(updated_state, component)) ||
      updated_state
  end

  defp reduce_component_zhang(state, component) do
    state
    |> Map.put(:variable_vertices, Enum.reduce(component, MapSet.new(), fn x, acc -> MapSet.put(acc, {:variable, x}) end))
    |> Map.put(:matching, %{})
    # |> reduce_state()

    #  |> then(fn %{components: subcomponents} = reduced_state ->
    #    Map.update!(state, :components, fn components ->
    #      components
    #      |> MapSet.delete(component)
    #      |> MapSet.union(subcomponents)
    #    end)
    #  end)
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

  defp matching_changed?(_matching, _vars, _var_index, :fixed) do
    true
  end

  defp matching_changed?(matching, vars, var_index, _domain_change) do
    var = get_variable(vars, var_index)

    case Map.get(matching, {:variable, var_index}) do
      {:value, matched_value} ->
        !contains?(var, matched_value)
      nil -> true
    end

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

  defp update_value_graph(graph, variables, var_index) do
    variable_vertex = {:variable, var_index}

    case BitGraph.neighbors(graph, variable_vertex) do
      nil ->
        graph
      neighbors ->
        var = get_variable(variables, var_index)
        Enum.reduce(
          neighbors,
          graph,
          fn {:value, value} = value_vertex, acc ->
            (contains?(var, value) && acc) ||
              BitGraph.delete_edge(acc, variable_vertex, value_vertex)
          end
        )
    end
  end
end
