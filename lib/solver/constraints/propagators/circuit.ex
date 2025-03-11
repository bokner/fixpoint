defmodule CPSolver.Propagator.Circuit do
  use CPSolver.Propagator

  @moduledoc """
  The propagator for 'circuit' constraint.
  """

  @impl true
  def reset(_args, %{domain_graph: graph} = state) do
    Map.put(state, :domain_graph, BitGraph.copy(graph))
  end

  def reset(_args, state) do
    state
  end

  @impl true
  def variables(args) do
    Enum.map(args, fn x_el -> set_propagate_on(x_el, :fixed) end)
  end

  @impl true
  def arguments(args) do
    Arrays.new(args, implementation: Aja.Vector)
  end

  @impl true
  def filter(all_vars, nil, changes) do
    filter(all_vars, initial_state(all_vars), changes)
  end

  def filter(all_vars, state, _changes) do
    case update_domain_graph(all_vars, state) do
      :complete ->
        :passive

      updated_state ->
        {:state, updated_state}
    end
  end

  defp initial_state(args) do
    l = Arrays.size(args)
    max_vertices = Enum.reduce(args, l, fn var, acc -> acc + size(var) end)

    {circuit, unfixed_vertices, domain_graph} =
      args
      |> Enum.with_index()
      |> Enum.reduce(
        {Arrays.new(List.duplicate(nil, l), implementation: Aja.Vector), [], BitGraph.new(max_vertices: max_vertices)},
        fn {var, idx}, {circuit_acc, unfixed_acc, graph_acc} ->
          initial_reduction(var, idx, l)
          fixed? = fixed?(var)

          circuit_acc =
            (fixed? && update_circuit(circuit_acc, idx, min(var))) ||
              circuit_acc

          unfixed_acc = (fixed? && unfixed_acc) || [idx | unfixed_acc]

          {circuit_acc, unfixed_acc,
           Enum.reduce(domain_values(var), graph_acc, fn value, g ->
             BitGraph.add_edge(g, idx, value)
           end)}
        end
      )

    %{
      domain_graph: domain_graph,
      circuit: Enum.reverse(circuit) |> Arrays.new(implementation: Aja.Vector),
      unfixed_vertices: unfixed_vertices
    }
  end

  defp initial_reduction(var, succ_value, circuit_length) do
    ## Cut the domain of variable to adhere to circuit definition.
    ## The values are 0-based indices.
    ## The successor can't point to itself.
    removeBelow(var, 0)
    removeAbove(var, circuit_length - 1)
    remove(var, succ_value)
  end

  ## 'vars' are successor variables in the circuit
  defp update_domain_graph(
         vars,
         %{domain_graph: graph, circuit: circuit, unfixed_vertices: unfixed_vertices} = _state
       ) do
    case reduce_graph(vars, graph, circuit, unfixed_vertices) do
      :fail ->
        fail()

      state ->
        (Enum.empty?(state.unfixed_vertices) &&
           :complete) ||
          state
    end
  end

  defp reduce_graph(vars, graph, circuit, unfixed_vertices) do
    reduce_graph(vars, graph, circuit, unfixed_vertices, [])
  end

  defp reduce_graph(vars, graph, circuit, [vertex | rest], remaining_unfixed) do
    var = Arrays.get(vars, vertex)

    if fixed?(var) do
      succ = min(var)
      {updated_graph, in_neighbours} = fix_vertex(graph, vertex, succ)

      ## As the successor is assigned to vertex, no other neighbours of successor can have it in their domains
      Enum.each(in_neighbours, fn in_n_vertex -> remove(Arrays.get(vars, in_n_vertex), succ) end)

      reduce_graph(
        vars,
        updated_graph,
        update_circuit(circuit, vertex, succ),
        rest,
        remaining_unfixed
      )
    else
      reduce_graph(vars, graph, circuit, rest, [vertex | remaining_unfixed])
    end
  end

  defp reduce_graph(_vars, graph, circuit, [], unfixed_vertices_map) do
    (check_graph(graph, circuit) &&
       %{
         domain_graph: graph,
         circuit: circuit,
         unfixed_vertices: unfixed_vertices_map
       }) ||
      fail()
  end

  defp fix_vertex(graph, vertex, value) do
    graph
    |> remove_out_edges(vertex, value)
    |> remove_in_edges(value, vertex)
  end

  ## Remove all out-edges for vertex_id except (vertex_id, successor_id) one
  defp remove_out_edges(graph, vertex_id, successor_id) do
    Enum.reduce(BitGraph.out_neighbors(graph, vertex_id), graph, fn
      neighbour_id, g_acc ->
        neighbour_id == successor_id && g_acc
        || delete_edge(g_acc, vertex_id, neighbour_id)
    end)
  end

  ## Remove all in-edges for successor_id except (vertex_id, successor_id)
  def remove_in_edges(graph, successor_id, vertex_id) do
    Enum.reduce(BitGraph.in_neighbors(graph, successor_id), {graph, []}, fn
      neighbour_id, acc when neighbour_id == vertex_id ->
        acc

      neighbour_id, {g_acc, in_neighbours_acc} ->
        {delete_edge(g_acc, neighbour_id, successor_id), [neighbour_id | in_neighbours_acc]}
    end)
  end

  def check_circuit(_partial_circuit, nil) do
    true
  end

  def check_circuit(partial_circuit, start_at) do
    check_circuit(partial_circuit, start_at, Arrays.get(partial_circuit, start_at), 1)
  end

  defp check_circuit(_partial_circuit, _started_at, nil, _step) do
    true
  end

  defp check_circuit(partial_circuit, started_at, currently_at, step)
       when started_at == currently_at do
    step == Arrays.size(partial_circuit)
  end

  defp check_circuit(partial_circuit, started_at, currently_at, step) do
    check_circuit(
      partial_circuit,
      started_at,
      Arrays.get(partial_circuit, currently_at),
      step + 1
    )
  end

  defp check_graph(graph, _fixed_vertices) do
    try do
    BitGraph.Algorithms.strong_components(graph, fn component ->
      throw({:single_scc?, component && (MapSet.size(component) == BitGraph.num_vertices(graph))})

      end)
    catch
      {:single_scc?, res} -> res
    end
  end

  defp update_circuit(circuit, idx, value) do
    Arrays.replace(circuit, idx, value)
    |> tap(fn partial_circuit -> check_circuit(partial_circuit, idx) || fail() end)
  end

  defp delete_edge(graph, vertex1, vertex2) do
    BitGraph.delete_edge(graph, vertex1, vertex2)
    |> tap(fn g ->
      Enum.empty?(BitGraph.out_neighbors(g, vertex1)) &&
        fail()
    end)
  end

  defp fail() do
    throw(:fail)
  end
end
