defmodule CPSolver.Propagator.AllDifferent.DC.BitGraph do
  use CPSolver.Propagator

  alias CPSolver.ValueGraph
  alias CPSolver.Propagator.AllDifferent.Utils, as: AllDiffUtils

  @moduledoc """
  The domain-consistent propagator for AllDifferent constraint,
  based on bipartite maximum matching.
  """
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
    state = (state && Map.put(state, :propagator_variables, vars)) || initial_state(vars)

    state
    |> apply_changes(changes)
    |> finalize()
  end

  defp finalize(state) do
    (entailed?(state) && :passive) ||
      {:state, state}
  end

  defp entailed?(%{sccs: sccs} = _state) do
    Enum.empty?(sccs)
  end

  defp apply_changes(
         %{
           sccs: _sccs,
           propagator_variables: _vars,
           value_graph: _graph
         } = state,
         changes
       ) do
    if Enum.empty?(changes) do
      state
    else
      ## Apply changes to affected SCCs
    end
  end

  def initial_state(vars) do
      %{value_graph: value_graph, left_partition: variable_vertices, fixed_matching: fixed_matching} =
        ValueGraph.build(vars, check_matching: true)


    %{
      propagator_variables: vars,
      variable_vertices: variable_vertices
    }
    |> Map.merge(reduction(vars, value_graph, variable_vertices, fixed_matching))
  end

  def reduction(vars, value_graph, variable_vertices, fixed_matching) do
    matching = find_matching(value_graph, variable_vertices, fixed_matching)

    %{value_graph: _reduced_graph, sccs: _sccs, matching: _matching} =
      reduce_graph(value_graph, vars, matching)
  end

  def find_matching(value_graph, variable_vertices, fixed_matching) do
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

  def reduce_graph(value_graph, variables, %{free: free_nodes, matching: matching} = _matching_record) do
    ## build residual graph
    value_graph
    |> BitGraph.add_vertex(:sink)
    |> then(fn g ->
      BitGraph.update_opts(g,
        neighbor_finder: residual_graph_neighbor_finder(g, variables, free_nodes, matching)
      )
    end)
    ## split to sccs
    |> AllDiffUtils.split_to_sccs(Map.keys(matching),
      AllDiffUtils.default_remove_edge_fun(variables))
    |> then(fn {sccs, reduced_graph} ->
      %{
        matching: matching,
        sccs: sccs,
        value_graph:
          reduced_graph
          |> BitGraph.delete_vertex(:sink)
          |> BitGraph.update_opts(neighbor_finder: ValueGraph.default_neighbor_finder(variables))
        }
    end)


  end


  defp residual_graph_neighbor_finder(value_graph, variables, free_nodes, matching) do
    num_variables = Arrays.size(variables)
    base_neighbor_finder = ValueGraph.matching_neighbor_finder(value_graph, variables, matching)
    free_node_indices = Stream.map(free_nodes, fn value_vertex -> BitGraph.V.get_vertex_index(value_graph, value_vertex) end)
    matching_value_indices = Stream.map(Map.values(matching), fn value_vertex -> BitGraph.V.get_vertex_index(value_graph, value_vertex) end)
    sink_node_index = BitGraph.V.get_vertex_index(value_graph, :sink)

    fn graph, vertex_index, direction ->
      neighbors = base_neighbor_finder.(graph, vertex_index, direction)
      ## By construction of value graph, the variable vertices go first,
      ## followed by value vertices; the last on is 'sink' vertex
        cond do
          vertex_index == sink_node_index  && direction == :out->
            matching_value_indices
          vertex_index == sink_node_index  && direction == :in ->
            free_node_indices
          vertex_index <= num_variables ->
            neighbors
          direction == :in && vertex_index in free_node_indices ->
            neighbors
          direction == :out && vertex_index in free_node_indices ->
            MapSet.new([sink_node_index])
          direction == :in && vertex_index in matching_value_indices ->
            MapSet.put(neighbors, sink_node_index)
          direction == :out && vertex_index in matching_value_indices ->
            neighbors

        end

      end
  end

  def reduce_residual_graph(residual_graph, vars, matching) do
    AllDiffUtils.split_to_sccs(residual_graph, Map.keys(matching),
    AllDiffUtils.default_remove_edge_fun(vars))
  end


  defp fail() do
    throw(:fail)
  end

end
