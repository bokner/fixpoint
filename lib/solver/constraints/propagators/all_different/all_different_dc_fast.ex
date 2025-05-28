defmodule CPSolver.Propagator.AllDifferent.DC.Fast do
  @moduledoc """
  A Fast Algorithm for Generalized Arc Consistency of the Alldifferent Constraint
  Xizhe Zhang, Qian Li and Weixiong Zhang
  https://www.ijcai.org/proceedings/2018/0194.pdf
  """

  use CPSolver.Propagator

  # alias CPSolver.Algorithms.Kuhn
  alias BitGraph.Algorithms.Matching.Kuhn
  alias CPSolver.ValueGraph
  alias CPSolver.Propagator.AllDifferent.Zhang

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

  def apply_changes(vars, %{sccs: sccs, type1_components: type1_components} = state, changes) do
    state
    |> reduce_components(type1_components, vars, changes)
    |> reduce_components(sccs, vars, changes)

    ## TODO: for debugging only
    initial_reduction(vars)
  end

  defp reduce_components(%{matching: matching} = state, components, vars, changes) do
    for component <- components, reduce: state do
      acc ->
        (matching_changed?(component, matching, vars) && update_state(acc, component, vars)) ||
          acc
    end
  end

  defp matching_changed?(component, matching, vars) do
    Enum.any?(component, fn {:variable, var_index} = var_vertex ->
      var = get_variable(vars, var_index)
      {:value, matched_value} = Map.get(matching, var_vertex)
      !contains?(var, matched_value)
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
