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
    Enum.map(args, fn x_el -> set_propagate_on(x_el, :domain_change) end)
  end

  @impl true
  def arguments(args) do
    Arrays.new(args, implementation: Aja.Vector)
  end

  @impl true
  def filter(all_vars, nil, changes) do
    filter(all_vars, initial_state(all_vars), changes)
  end

  def filter(all_vars, state, changes) do
    updated_state = apply_changes(all_vars, state, changes)
    check_state(updated_state) &&
      (completed?(updated_state) && :passive
        ||
        {:state, updated_state})
        || fail()
  end

  defp initial_state(args) do
    l = Arrays.size(args)
    max_vertices = Enum.reduce(args, l, fn var, acc -> acc + size(var) end)

    domain_graph =
      args
      |> Enum.with_index()
      |> Enum.reduce(
        BitGraph.new(max_vertices: max_vertices),
        fn {var, idx}, graph_acc ->
          initial_reduction(var, idx, l)

           Enum.reduce(domain_values(var), graph_acc, fn value, g ->
             BitGraph.add_edge(g, idx, value)
           end)
        end
      )

    %{
      domain_graph: domain_graph
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
  defp apply_changes(
         vars,
         %{domain_graph: graph} = state,
         changes
       ) do
        Map.put(state, :domain_graph,
        Enum.reduce(changes, graph, fn {var_idx, domain_change}, graph_acc ->
          reduce_var(vars, var_idx, graph_acc, domain_change)
        end)
        )
      end

  defp reduce_var(vars, var_idx, graph, :fixed) do
    successor = min(Propagator.arg_at(vars, var_idx))
    ## No other variables can share the successor, so
    ## we will remove the successor from their domains
    Enum.reduce(BitGraph.in_neighbors(graph, successor), graph, fn predessor, graph_acc ->
      predessor == var_idx && graph_acc ||
      (
        res = remove(Propagator.arg_at(vars, predessor), successor)
        g = BitGraph.delete_edge(graph_acc, predessor, successor)
          reduce_var(vars, predessor, g, res)
      )
    end)
  end


  defp reduce_var(vars, var_idx, graph, _domain_change) do
    new_successors = domain_values(Propagator.arg_at(vars, var_idx))
    current_successors = BitGraph.out_neighbors(graph, var_idx)
    ## `new_successors` is always a subset of `current_successors`
    ## We remove edges that are a difference between these two sets
    Enum.reduce(MapSet.difference(current_successors, new_successors),
      graph, fn s, graph_acc ->
        BitGraph.delete_edge(graph_acc, var_idx, s)
      end)
  end

  defp check_state(%{domain_graph: graph} = _state) do
    BitGraph.Algorithms.strongly_connected?(graph, algorithm: Enum.random([:tarjan, :kozaraju]))
  end

  defp completed?(%{domain_graph: graph} = _state) do
    BitGraph.num_vertices(graph) == BitGraph.num_edges(graph)
  end

  defp fail() do
    throw(:fail)
  end
end
