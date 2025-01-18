defmodule CPSolver.Propagator.AllDifferent.DC.Fast do
  @moduledoc """
  A Fast Algorithm for Generalized Arc Consistency of the Alldifferent Constraint
  Xizhe Zhang, Qian Li and Weixiong Zhang
  https://www.ijcai.org/proceedings/2018/0194.pdf
  """

  use CPSolver.Propagator

  alias CPSolver.Propagator.AllDifferent.DC
  alias CPSolver.Variable.Interface
  alias CPSolver.Algorithms.Kuhn


  @impl true
  def arguments(args) do
    Arrays.new(args, implementation: Aja.Vector)
  end

  @impl true
  def variables(args) do
    Enum.map(args, fn x_el -> set_propagate_on(x_el, :domain_change) end)
  end

  @impl true
  def filter(all_vars, _state, _changes) do
    {:state, %{value_graph: reduce(all_vars)}}
  end

  def reduce(variables) do
    reduce(variables, reduction_callback(variables))
  end

  def reduce(variables, reduction_callback) do
    {value_graph, variable_vertices, value_vertices, partial_matching} =
      DC.build_value_graph(variables)

    case Kuhn.run(
           value_graph,
           variable_vertices,
           partial_matching,
           MapSet.size(variable_vertices)
         ) do
      nil ->
        fail()

      matching ->
        reduce(value_graph, matching, variable_vertices, value_vertices, reduction_callback)
    end
  end

  defp reduction_callback(variables) do
    fn var_idx, value ->
      Interface.remove(Propagator.arg_at(variables, var_idx), value)
    end
  end

  defp fail() do
    throw(:fail)
  end

  def reduce(
        value_graph,
        matching,
        _variable_vertices,
        value_vertices,
        remove_edge_callback \\ fn _var_idx, _value -> :noop end
      ) do
    ## Flip edges that are in matching
    graph = flip_matching(value_graph, matching)

    free_nodes = free_nodes(matching, value_vertices)
    ## Build sets Γ(A) (neighbors of free value vertices)
    ## and A (allowed nodes)
    ga_da_set =
      Enum.reduce(free_nodes, free_nodes, fn vertex, ga_set_acc ->
        ## Free node
        collect_GA_nodes(graph, vertex, ga_set_acc)
      end)

    # ga_c = MapSet.difference(variable_vertices, ga_da_set)
    graph
    |> remove_type1_edges(ga_da_set, remove_edge_callback)
    |> then(fn {t1_graph, complement_vertices} ->
      remove_type2_edges(t1_graph, complement_vertices, remove_edge_callback)
    end)
  end

  def free_nodes(matching, value_vertices) do
    Enum.reduce(matching, value_vertices, fn {value_vertex, _var}, acc ->
      MapSet.delete(acc, value_vertex)
    end)
  end

  def flip_matching(value_graph, matching) do
    Enum.reduce(matching, value_graph, fn {val, var}, g_acc ->
      Graph.delete_edge(g_acc, val, var) |> Graph.add_edge(var, val)
    end)
  end

  def collect_GA_nodes(graph, vertex, acc) do
    Enum.reduce(Graph.out_neighbors(graph, vertex), acc, fn variable_vertex, acc2 ->
      if MapSet.member?(acc2, variable_vertex) do
        acc2
      else
        MapSet.union(acc2, alternating_path(graph, variable_vertex))
      end
    end)
  end

  ## Alternating path starting from (and including) vertex.
  ## Alternating path always
  def alternating_path(graph, vertex) do
    alternating_path(graph, vertex, MapSet.new([vertex]))
  end

  def alternating_path(graph, vertex, acc) do
    case Graph.out_neighbors(graph, vertex) do
      [] ->
        acc

      [next_in_path | rest] ->
        (MapSet.member?(acc, next_in_path) && acc) ||
          alternating_path(graph, rest, MapSet.put(acc, next_in_path))
    end
  end

  def remove_type1_edges(graph, ga_da_set, callback) do
    Enum.reduce(Graph.vertices(graph), {graph, MapSet.new()}, fn
      {:value, _value} = value_vertex, {graph_acc, complement_acc} = acc ->
        if MapSet.member?(ga_da_set, value_vertex) do
          acc
        else
          {graph_acc, MapSet.put(complement_acc, value_vertex)}
        end

      {:variable, var_idx} = variable_vertex, {graph_acc, complement_acc} ->
        if MapSet.member?(ga_da_set, variable_vertex) do
          ## Take all edges that are not in matching
          ## (the ones that are will be 'out' edges
          graph_acc =
            Enum.reduce(
              Graph.in_neighbors(graph_acc, variable_vertex),
              graph_acc,
              fn value_vertex, graph_acc2 ->
                if MapSet.member?(ga_da_set, {:value, value} = value_vertex) do
                  ## This value node is in Dc-A (as by the paper)
                  graph_acc2
                else
                  ## This value node is not in Dc-A, remove the edge
                  callback.(var_idx, value)
                  Graph.delete_edge(graph_acc2, value_vertex, variable_vertex)
                end
              end
            )

          {graph_acc, complement_acc}
        else
          {graph_acc, MapSet.put(complement_acc, variable_vertex)}
        end
    end)
  end

  def remove_type2_edges(value_graph, vertices, callback) do
    type2_graph = Graph.subgraph(value_graph, vertices)
    sccs = Graph.strong_components(type2_graph)
    ## Make maps var_vertex => scc_id, val_vertex => scc_id
    {_idx, var_scc_map, value_scc_map} =
      Enum.reduce(
        sccs,
        {0, Map.new(), Map.new()},
        fn vertices, {idx, variable_map_acc, value_map_acc} = _acc ->
          {var_map, val_map} =
            Enum.reduce(vertices, {variable_map_acc, value_map_acc}, fn
              {:value, _} = vertex, {variable_map_acc2, value_map_acc2} ->
                {variable_map_acc2, Map.put(value_map_acc2, vertex, idx)}

              {:variable, _} = vertex, {variable_map_acc2, value_map_acc2} ->
                {Map.put(variable_map_acc2, vertex, idx), value_map_acc2}
            end)

          {idx + 1, var_map, val_map}
        end
      )

    ## Remove the cross-edges
    Enum.reduce(var_scc_map, value_graph, fn {{:variable, var_idx} = var_vertex, scc_id},
                                             graph_acc ->
      Enum.reduce(Graph.in_edges(graph_acc, var_vertex), graph_acc, fn
        %{v1: {:value, value} = value_vertex} = _edge, graph_acc2 ->
          case Map.get(value_scc_map, value_vertex)  do
            ## Not a cross-edge
            nil -> graph_acc2
            value_scc when value_scc == scc_id ->
              graph_acc2
            _different_scc ->
              ## Cross-edge
            callback.(var_idx, value)
            Graph.delete_edge(graph_acc2, value_vertex, var_vertex)
          end
      end)
    end)
  end
end
