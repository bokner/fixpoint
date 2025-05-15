defmodule CPSolver.Propagator.AllDifferent.DC.Fast do
  @moduledoc """
  A Fast Algorithm for Generalized Arc Consistency of the Alldifferent Constraint
  Xizhe Zhang, Qian Li and Weixiong Zhang
  https://www.ijcai.org/proceedings/2018/0194.pdf
  """

  use CPSolver.Propagator

  #alias CPSolver.Algorithms.Kuhn
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
      (state && apply_changes(vars, state, changes) ||
      initial_reduction(vars))
      |> finalize()
  end

  defp finalize(state) do
    Enum.empty?(state.components) && :passive ||
      {:state, state}
  end

  def initial_reduction(vars) do
    initial_state = initial_state(vars)
    reduce_state(initial_state)
  end

  def initial_state(variables) do
    %{graph: value_graph, left_partition: variable_vertices, fixed: partial_matching} =
      ValueGraph.build(variables)

    %{
      value_graph: value_graph,
      variable_vertices: variable_vertices,
      matching: partial_matching,
      reduction_callback: build_reduction_callback(variables)
    }
  end

  defp build_reduction_callback(variables) do
    fn graph, var_vertex, value_vertex ->
      remove(Propagator.arg_at(variables, get_index(var_vertex)), get_index(value_vertex))
      BitGraph.delete_edge(graph, get_variable_vertex(var_vertex), get_value_vertex(value_vertex))
    end
  end

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


  def reduce_state(%{
        value_graph: value_graph,
        matching: partial_matching,
        variable_vertices: variable_vertices,
        reduction_callback: reduction_callback
      } = _state) do
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

  defp fail() do
    throw(:fail)
  end

  def reduce_impl(value_graph, variable_vertices, partial_matching, remove_edge_fun) do
    %{free: free_nodes, matching: matching} = find_matching(value_graph, variable_vertices, partial_matching)
    value_graph
    |> Zhang.remove_type1_edges(free_nodes, matching, remove_edge_fun)
    |> Zhang.remove_type2_edges(remove_edge_fun)
  end

  def apply_changes(_vars, state, changes) when is_nil(changes) or map_size(changes) == 0 do
    state
  end

  def apply_changes(vars, state, changes) do
    :todo
    initial_reduction(vars)
  end

end
