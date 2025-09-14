defmodule CPSolver.Propagator.Circuit do
  use CPSolver.Propagator

  alias Iter.{Iterable.FlatMapper, Iterable.Mapper}
  import CPSolver.Utils

  @moduledoc """
  The propagator for 'circuit' constraint.
  """

  @impl true
  def variables(args) do
    Enum.map(args, fn x_el -> set_propagate_on(x_el, :domain_change) end)
  end

  @impl true
  def arguments(args) do
    Arrays.new(args, implementation: Aja.Vector)
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

  def reduce_state(state, changes) do
    %{domain_graph: graph} = updated_state = apply_changes(state, changes)
    BitGraph.Algorithm.strongly_connected?(graph, algorithm: :tarjan) && updated_state
    || fail()

  end

  defp initial_state(variables) do
    l = Arrays.size(variables)

    domain_graph =
      variables
      |> Enum.with_index()
      |> Enum.reduce(
        BitGraph.new(max_vertices: l, allocate_adjacency_table?: false),
        fn {var, idx}, graph_acc ->
          initial_reduction(var, idx, l)
          BitGraph.add_vertex(graph_acc, idx)
        end
      )

    %{
      domain_graph: domain_graph,
    }
    |> update_state(variables)
  end

  defp update_state(state, variables) do
    state
    |> Map.update!(:domain_graph,
      fn graph ->
        BitGraph.set_neighbor_finder(graph, neighbor_finder(variables))
      end)
    |> Map.put(:propagator_variables, variables)
  end

  defp finalize(state) do
      (completed?(state) && :passive
        ||
      {:state, state})
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
         %{propagator_variables: vars, domain_graph: graph} = state,
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
    successor_vertex_index = successor + 1
    iterate_reduction(BitGraph.V.in_neighbors(graph, successor_vertex_index), successor, graph, vars, var_idx)
  end

  defp reduce_var(_vars, _var_idx, _graph, _domain_change) do
    :ok
  end


  defp iterate_reduction(neighbors, successor, graph, vars, var_idx) do
    iterate(neighbors, :ok, fn predessor, _acc ->
      predessor_var_index = predessor - 1
      if predessor_var_index == var_idx do
        {:cont, :ok}
      else
        res = remove(get_variable(vars, predessor_var_index), successor)
        {:cont, reduce_var(vars, predessor_var_index, graph, res)}
      end
    end)
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
        vars
        |> get_variable(vertex_index - 1)
        |> domain_iterator()
      _graph, vertex_index, :in ->
        FlatMapper.new(1..Arrays.size(vars),
          fn idx ->
            contains?(get_variable(vars, idx - 1), vertex_index - 1) && [idx] || []
          end
        )
    end
  end

  def domain_iterator(variable) do
    variable
    |> Interface.iterator()
    |> Mapper.new(fn val -> val + 1 end)
  end

  def domain_set(variable) do
    MapSet.new(domain_values(variable), fn val -> val + 1 end)
  end
end
