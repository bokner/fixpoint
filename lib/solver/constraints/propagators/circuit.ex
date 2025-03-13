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
      reduce_graph(vars, graph, circuit, rest, [vertex | remaining_unfixed])
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

  defp check_graph(graph, _fixed_vertices) do
    try do
    BitGraph.Algorithms.strong_components(graph, fn component, _dfs_state ->
      throw({:single_scc?, component && (MapSet.size(component) == BitGraph.num_vertices(graph))})

      end)
    catch
      {:single_scc?, res} -> res
    end
  end

  defp fail() do
    throw(:fail)
  end
end
