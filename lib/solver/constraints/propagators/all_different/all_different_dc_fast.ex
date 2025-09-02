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
    |> reduce_state(changes)
    |> finalize()
  end

  defp update_state(state, vars) do
    state
    |> Map.put(:propagator_variables, vars)
    |> then(fn state -> Map.put(state, :reduction_callback, reduction_callback(state)) end)
  end

  defp finalize(:all_fixed) do
    :passive
  end

  defp finalize(state) do
    (entailed?(state) && :passive) ||
      {:state, state}
  end

  def entailed?(%{components: components, unfixed_indices: unfixed_indices} = _state) do
    Enum.empty?(components) || Enum.empty?(unfixed_indices)
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
      fixed_values: fixed_values,
      } = ValueGraph.build(variables, check_matching: true)

    %{
      value_graph: value_graph,
      variable_vertices: variable_vertices,
      fixed_matching: fixed_matching,
      unfixed_indices: unfixed_indices,
      fixed_values: fixed_values,
      components: MapSet.new(List.wrap(variable_vertices)) ## We start with a single component wrapped in a set
    }
    |> update_state(variables)
  end

  defp reduction_callback(%{
      propagator_variables: variables
      } = _state) do
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
          fixed_matching: fixed_matching,
          propagator_variables: variables,
          reduction_callback: remove_edge_fun,
          fixed_values: fixed_values,
          unfixed_indices: unfixed_indices
        } = state, changes \\ Map.new()) do

      {unfixed_indices, fixed_values, fixed_matching} = forward_checking(changes, unfixed_indices, fixed_values, fixed_matching, variables)
      if Enum.empty?(unfixed_indices) do
        :all_fixed
      else
      %{free: free_nodes, matching: matching} =
        value_graph
        |> reset_value_graph(variables)
        |> find_matching(
          variable_vertices,
          fixed_matching
          )

      %{value_graph: reduced_value_graph, components: components} =
        value_graph
        |> BitGraph.set_neighbor_finder(ValueGraph.matching_neighbor_finder(value_graph, variables, matching, free_nodes))
        |> Zhang.reduce(free_nodes, matching, remove_edge_fun)

      state
      |> Map.put(:value_graph, reduced_value_graph)
      |> Map.put(:components, components)
      |> Map.replace!(:unfixed_indices, unfixed_indices)
      |> Map.replace!(:fixed_values, fixed_values)
      |> Map.replace!(:fixed_matching, fixed_matching)
    end
  end

  defp reset_value_graph(value_graph, vars) do
        BitGraph.set_neighbor_finder(value_graph,
          ValueGraph.default_neighbor_finder(vars)
        )
  end

  defp forward_checking(_changes, unfixed_indices, fixed_values, fixed_matching, variables) do
      {updated_unfixed_indices, updated_fixed_values} = Utils.forward_checking(variables, unfixed_indices, fixed_values)
      ## Update fixed matching
      updated_fixed_matching =
        updated_unfixed_indices
        |> Enum.reduce(fixed_matching, fn unfixed_idx, acc ->
          if unfixed_idx in unfixed_indices do
            acc
          else
            Map.put(acc, {:variable, unfixed_idx}, {:value, min(Propagator.arg_at(variables, unfixed_idx))})
          end
        end)
      {updated_unfixed_indices, updated_fixed_values, updated_fixed_matching}
  end
end
