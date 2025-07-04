defmodule CPSolver.Propagator.Circuit do
  use CPSolver.Propagator

  @moduledoc """
  The propagator for 'circuit' constraint.
  """

  @impl true
  def reset(args, %{domain_graph: graph} = state) do
    state
    |> Map.put(:domain_graph, BitGraph.update_opts(graph, neighbor_finder: neighbor_finder(args)))
    |> Map.put(:propagator_variables, args)
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

    domain_graph =
      args
      |> Enum.with_index()
      |> Enum.reduce(
        BitGraph.new(max_vertices: l),
        fn {var, idx}, graph_acc ->
          initial_reduction(var, idx, l)
          BitGraph.add_vertex(graph_acc, idx)
        end
      )
      |> BitGraph.update_opts(neighbor_finder: neighbor_finder(args))

    %{
      domain_graph: domain_graph,
      propagator_variables: args
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
        ## Side effect - the domain graph doesn't need to be updated,
        ## as the graph's neighbor finder for is backed by variable domains.
        Enum.each(changes, fn {var_idx, domain_change} ->
          reduce_var(vars, var_idx, graph, domain_change)
        end)

        state

      end

  defp reduce_var(vars, var_idx, graph, :fixed) do
    successor = min(get_variable(vars, var_idx))
    short_loop_check(vars, successor)
    ## No other variables can share the successor, so
    ## we will remove the successor from their domains
    Enum.each(BitGraph.in_neighbors(graph, successor), fn predessor ->
      predessor == var_idx ||
      (
        res = remove(get_variable(vars, predessor), successor)
        reduce_var(vars, predessor, graph, res)
      )
    end)
  end


  defp reduce_var(_vars, _var_idx, _graph, _domain_change) do
    :ok
  end

  defp short_loop_check(vars, fixed_value) do
    short_loop_check(vars, fixed_value, MapSet.new([fixed_value]))
  end

  defp short_loop_check(vars, fixed_value, fixed_chain) do
    next = get_variable(vars, fixed_value)
    if fixed?(next) do
      next_value = min(next)
      if next_value in fixed_chain do
        ## short loop?
        if MapSet.size(fixed_chain) < Arrays.size(vars), do: fail()
        ## follow the chain
        short_loop_check(vars, next_value, MapSet.put(fixed_chain, next_value))
      end
    end
  end

  defp check_state(%{domain_graph: graph} = _state) do
    BitGraph.Algorithms.strongly_connected?(graph, algorithm: Enum.random([:tarjan, :kozaraju]))
  end

  defp completed?(%{propagator_variables: variables} = _state) do
    Enum.all?(variables, fn var -> fixed?(var) end)
  end

  defp fail() do
    throw(:fail)
  end

  defp get_variable(vars, var_index) do
    Propagator.arg_at(vars, var_index)
  end

  defp neighbor_finder(vars) do
    fn _graph, vertex_index, :out ->
        Stream.map(domain_values(get_variable(vars, vertex_index - 1)), fn val -> val + 1 end)
      _graph, vertex_index, :in ->
        for v <- vars, reduce: {1, MapSet.new()} do
          {idx, n_acc} ->
             {idx + 1,
             contains?(v, vertex_index - 1) && MapSet.put(n_acc, idx) || n_acc}
        end
        |> elem(1)
    end
  end
end
