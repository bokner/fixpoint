defmodule CPSolver.Propagator.AllDifferent.DC.V2 do
  use CPSolver.Propagator

  alias CPSolver.ValueGraph
  alias CPSolver.Propagator.AllDifferent.Utils, as: AllDiffUtils
  alias CPSolver.Utils, as: SolverUtils

  @moduledoc """
  The domain-consistent propagator for AllDifferent constraint,
  based on:
  J.-C. Régin, A filtering algorithm for constraints of difference in CSPs
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
  def reset(args, %{value_graph: graph} = state) do
    state
    |> Map.put(:value_graph, BitGraph.update_opts(graph, neighbor_finder: ValueGraph.default_neighbor_finder(args)))
    |> Map.put(:propagator_variables, args)
  end

  def reset(_args, state) do
    state
  end

  @impl true
  def filter(vars, state, changes) do
    state = (state && apply_changes(state, changes)) || initial_state(vars)
    finalize(state)
  end

  defp finalize(state) do
    (entailed?(state) && :passive) ||
      {:state, state}
  end

  defp entailed?(%{sccs: sccs} = _state) do
    Enum.empty?(sccs)
  end

  def apply_changes(state, changes, repetitions) do
    Enum.reduce_while(1..repetitions, state, fn _, acc ->
      new_acc = apply_changes(acc, changes)
      (entailed?(new_acc) || new_acc.sccs == acc.sccs) && {:halt, acc} || {:cont, apply_changes(acc, changes)}
    end)
  end

  def apply_changes(
         %{
           sccs: sccs
         } = state,
         _changes
       ) do
      ## Apply changes to affected SCCs
      Enum.reduce(sccs, Map.put(state, :sccs, MapSet.new()),
        fn component, state_acc ->
        %{value_graph: reduced_graph, sccs: derived_sccs} = reduce_component(component, state_acc)
        state_acc
        |> Map.put(:value_graph, reduced_graph)
        |> Map.update!(:sccs, fn existing -> MapSet.union(existing, derived_sccs) end)
        end)
  end

  def initial_state(vars) do
    %{value_graph: value_graph, left_partition: variable_vertices, fixed_matching: _fixed_matching} =
      ValueGraph.build(vars, check_matching: true)

    reduce_component(MapSet.new(variable_vertices, fn {:variable, var_index} -> var_index end),
      value_graph, vars)
    |> Map.put(:propagator_variables, vars)
  end


  def reduce_component(component,
    %{
      propagator_variables: vars,
      value_graph: value_graph
    } = _state) do
      reduce_component(component, value_graph, vars)
    end

  def reduce_component(component, value_graph, vars) do
    reduction(vars, value_graph, MapSet.new(component,
      fn component_index -> {:variable, component_index}
    end), %{})
  end

  def reduction(vars, value_graph, variable_vertices, fixed_matching) do
    matching = find_matching(value_graph, variable_vertices, fixed_matching)

    %{value_graph: _reduced_graph, sccs: _sccs} =
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
    value_graph
    |> build_residual_graph(variables, matching, free_nodes)
    |> reduce_residual_graph(variables, matching)
    |> then(fn {sccs, reduced_graph} ->
      %{
        sccs: sccs,
        value_graph:
          reduced_graph
          |> remove_sink_node()
          |> BitGraph.update_opts(neighbor_finder: ValueGraph.default_neighbor_finder(variables))
        }
    end)
  end

  def build_residual_graph(graph, variables, matching, free_nodes) do
    graph
    |> add_sink_node(free_nodes)
    |> then(fn g ->
      BitGraph.update_opts(g,
        neighbor_finder: residual_graph_neighbor_finder(g, variables, matching, free_nodes)
      )
    end)
  end

  defp add_sink_node(graph, free_nodes) do
    Enum.empty?(free_nodes) && graph ||
    BitGraph.add_vertex(graph, :sink)
  end

  defp remove_sink_node(graph) do
    case BitGraph.V.get_vertex_index(graph, :sink) do
      nil -> graph
      sink_index -> BitGraph.V.delete_vertex(graph, sink_index)
    end
  end

  defp residual_graph_neighbor_finder(value_graph, variables, matching, free_nodes) do
    num_variables = ValueGraph.get_variable_count(value_graph)
    base_neighbor_finder = ValueGraph.matching_neighbor_finder(value_graph, variables, matching, free_nodes)
    free_node_indices = Stream.map(free_nodes, fn value_vertex -> BitGraph.V.get_vertex_index(value_graph, value_vertex) end)
    matching_value_indices = Stream.map(Map.values(matching), fn value_vertex -> BitGraph.V.get_vertex_index(value_graph, value_vertex) end)
    sink_node_index = BitGraph.V.get_vertex_index(value_graph, :sink)

    fn _graph, nil, _direction ->
      ## "Stray" vertex index.
      ## This could happen if the vertex is not in the graph,
      ## for instance, as a result of it being removed during graph processing;
      ## TODO: review
      MapSet.new()

      graph, vertex_index, direction ->
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
          true ->
            MapSet.new()
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
