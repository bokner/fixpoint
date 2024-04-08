defmodule CPSolver.Propagator.Circuit do
  use CPSolver.Propagator

  @moduledoc """
  The propagator for 'circuit' constraint.
  """

  @impl true
  def variables(args) do
    Enum.map(args, fn x_el -> set_propagate_on(x_el, :fixed) end)
  end

  @impl true
  def filter(args) do
    filter(args, initial_state(args))
  end

  @impl true
  def filter(args, nil) do
    filter(args)
  end

  def filter(all_vars, state) do
    case update_domain_graph(all_vars, state) do
      :complete ->
        :passive

      updated_state ->
        {:state, updated_state}
    end
  end

  defp initial_state(args) do
    l = length(args)

    domain_graph =
      args
      |> Enum.with_index()
      |> Enum.reduce(Graph.new(), fn {var, idx}, graph_acc ->
        initial_reduction(var, idx, l)

        Enum.reduce(domain(var) |> Domain.to_list(), graph_acc, fn value, g ->
          Graph.add_edge(g, idx, value)
        end)
      end)

    %{
      domain_graph: domain_graph,
      circuit: circuit(args),
      unfixed_vertices: Graph.vertices(domain_graph)
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
         %{domain_graph: %Graph{} = graph, unfixed_vertices: unfixed_vertices} = _current_state
       ) do
    case reduce_graph(graph, vars, unfixed_vertices) do
      :fail ->
        fail()

      {updated_graph, updated_unfixed_vertices} ->
        (MapSet.size(updated_unfixed_vertices) == 0
        #&& hamiltonian?(vars)
        && :complete) ||
          %{domain_graph: updated_graph, unfixed_vertices: updated_unfixed_vertices}
    end
  end

  defp reduce_graph(graph, vars, unfixed_vertices) when is_map(unfixed_vertices) do
    reduce_graph(graph, vars, MapSet.to_list(unfixed_vertices))
  end

  defp reduce_graph(graph, vars, unfixed_vertices) when is_list(unfixed_vertices) do
    reduce_graph(graph, vars, unfixed_vertices, MapSet.new())
  end

  ##
  @spec reduce_graph(
          graph :: Graph.t(),
          vars :: [Variable.t()],
          unfixed_vertices :: [integer()],
          remaining_unfixed_vertices :: MapSet.t()
        ) ::
          {Graph.t(), [integer]}

  ## All unfixed vertices have been processed
  defp reduce_graph(%Graph{} = graph, _vars, [], remaining_unfixed_vertices) do
    (check_graph(graph, remaining_unfixed_vertices) &&
       {graph, remaining_unfixed_vertices}) || fail()
  end

  defp reduce_graph(
         %Graph{} = graph,
         vars,
         [idx | rest] = _unfixed_vertices,
         ids_to_revisit
       ) do
    ## Check if the (unfixed) vertex has already been scheduled for the next stage
    if MapSet.member?(ids_to_revisit, idx) do
      reduce_graph(graph, vars, rest, ids_to_revisit)
    else
      var = Enum.at(vars, idx)

      if fixed?(var) do
        successor_vertex = min(var)

        {reduced_graph, reduced_unfixed_vertices} =
          reduce_with_fixed(graph, vars, idx, successor_vertex, ids_to_revisit)

        reduce_graph(
          reduced_graph,
          vars,
          rest,
          MapSet.difference(ids_to_revisit, reduced_unfixed_vertices)
        )
      else
        reduce_graph(graph, vars, rest, MapSet.put(ids_to_revisit, idx))
      end
    end
  end

  defp reduce_with_fixed(graph, vars, idx, successor, unfixed_vertices) do
    graph
    |> remove_out_edges(idx, successor)
    |> remove_in_edges(successor, idx, vars, unfixed_vertices)
  end

  ## Remove all out-edges for vertex_id except (vertex_id, successor_id) one
  defp remove_out_edges(%Graph{} = graph, vertex_id, successor_id) do
    Enum.reduce(Graph.out_edges(graph, vertex_id), graph, fn
      %{v2: neighbour_id} = _out_edge, g_acc when neighbour_id == successor_id -> g_acc
      %{v2: neighbour_id} = _out_edge, g_acc -> delete_edge(g_acc, vertex_id, neighbour_id)
    end)
  end

  ## Remove all in-edges for successor_id except (vertex_id, successor_id)
  def remove_in_edges(%Graph{} = graph, successor_id, vertex_id, vars, unfixed_vertices) do
    Enum.reduce(Graph.in_edges(graph, successor_id), {graph, unfixed_vertices}, fn
      %{v1: neighbour_id} = _in_edge, acc when neighbour_id == vertex_id ->
        acc

      %{v1: neighbour_id} = _in_edge, {g_acc, unfixed_acc} ->
        var = Enum.at(vars, neighbour_id)

        {delete_edge(g_acc, neighbour_id, successor_id),
         (:fixed == remove(var, successor_id) && MapSet.delete(unfixed_acc, successor_id)) ||
           unfixed_acc}
    end)
  end

  defp check_graph(%Graph{} = graph, _fixed_vertices) do
    length(Graph.strong_components(graph)) == 1
  end

  defp delete_edge(%Graph{} = graph, vertex1, vertex2) do
    Graph.delete_edge(graph, vertex1, vertex2)
    |> tap(fn g ->
      (Graph.in_neighbors(g, vertex2) == [] ||
         Graph.out_neighbors(g, vertex1) == []) &&
        fail()
    end)
  end

  ## Builds (partial) circuits from fixed values of variables
  defp circuit(vars) do
    Enum.map(vars, fn var ->
      (fixed?(var) && min(var)) || nil
    end)
  end

  # defp check_for_cycles(partial_circuit) do
  #   ## {current_position, path_length, path_start}
  #   initial_state = {0, 0, nil}
  #   partial_circuit
  #   |> Enum.reduce(partial_circuit, {0, 0, nil},
  #     fn _succ, {current_position, path_length, path_start} ->
  #       case Enum.at(current_position) do
  #         nil ->
  #       end
  #     end)
  # end

  defp hamiltonian?(vars) do
    {cycle_length, _current} =
      Enum.reduce_while(vars, {1, 0}, fn _succ, {length_acc, succ_acc} = acc ->
        var = Enum.at(vars, succ_acc)

        if fixed?(var) do
          next = min(var)

          if next == 0 do
            {:halt, acc}
          else
            {:cont, {length_acc + 1, next}}
          end
        else
          {:halt, {0, :not_fixed}}
        end
      end)

    cycle_length == length(vars)
  end

  defp fail() do
    throw(:fail)
  end
end
