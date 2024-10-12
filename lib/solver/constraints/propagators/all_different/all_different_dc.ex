defmodule CPSolver.Propagator.AllDifferent.DC do
  use CPSolver.Propagator

  alias CPSolver.Algorithms.Kuhn

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
  def filter(all_vars, state, changes) do
    new_state = state && filter_impl(all_vars, state, changes) ||
      initial_state(all_vars)

    new_state == :resolved && :passive ||
    {:state, new_state}
  end

  defp filter_impl(all_vars, state, changes) do
    :todo
  end


  def initial_state(vars) do
    {value_graph, variable_vertices, partial_matching} = build_value_graph(vars)
    reduction(vars, value_graph, variable_vertices, partial_matching)

  end

  def reduction(vars, value_graph, variable_vertices, partial_matching) do
    maximum_matching = compute_maximum_matching(value_graph, variable_vertices, partial_matching)
    {residual_graph, sccs} =
      build_residual_graph(value_graph, maximum_matching)
      |> reduce_residual_graph(vars)

    Enum.empty?(sccs) && :resolved ||
    %{
      sccs: sccs,
      matching: maximum_matching,
      residual_graph: residual_graph
    }
  end

  def build_value_graph(vars) do
    Enum.reduce(Enum.with_index(vars), {Graph.new(), [], Map.new()}, fn {var, idx},
                                                                        {graph_acc, var_ids_acc,
                                                                         partial_matching_acc} ->
      var_vertex = {:variable, idx}
      var_ids_acc = [var_vertex | var_ids_acc]
      ## If the variable fixed, it's already in matching.
      ## We do not have to add it to the value graph.
      if fixed?(var) do
        {graph_acc, var_ids_acc, Map.put(partial_matching_acc, {:value, min(var)}, var_vertex)}
      else
        domain = domain(var) |> Domain.to_list()

        {Enum.reduce(domain, graph_acc, fn d, graph_acc2 ->
           Graph.add_edge(graph_acc2, {:value, d}, var_vertex)
         end), var_ids_acc, partial_matching_acc}
      end
    end)
  end

  def compute_maximum_matching(value_graph, variable_ids, partial_matching) do
    Kuhn.run(value_graph, variable_ids, partial_matching)
    |> tap(fn matching -> map_size(matching) < length(variable_ids) && fail() end)
  end

  defp build_residual_graph(value_graph, maximum_matching) do
    ## The matching edges connect variables to values
    Enum.reduce(
      Graph.edges(value_graph),
      value_graph,
      fn %{
           v1: {:value, _value} = v1,
           v2: {:variable, _var_id} = v2
         } = _edge,
         residual_graph_acc ->
        case Map.get(maximum_matching, v1) do
          nil ->
            ## The vertices of unmatched values are connected to the sink vertex
            Graph.add_edge(residual_graph_acc, :sink, v1)

          ## The edge is in matching - reverse
          var when var == v2 ->
            Graph.delete_edge(residual_graph_acc, v1, v2)
            |> Graph.add_edge(v2, v1)

          _var ->
            ## The value is matched, but the edge is not in matching -
            ## connect value vertex to the sink
            Graph.add_edge(residual_graph_acc, v1, :sink)
        end
      end
    )
  end

  defp reduce_residual_graph(graph, vars) do
    sccs = Graph.strong_components(graph)
    {remove_cross_edges(graph, sccs, vars), remove_empty_sccs(sccs)}
  end

  defp remove_cross_edges(graph, sccs, vars) do
    Enum.reduce(sccs, graph, fn component, graph_acc ->
      component_set = MapSet.new(component)
      Enum.reduce(component_set, graph_acc,
        fn {:variable, _id} = _vertex, graph_acc2 ->
          graph_acc2
          :sink, graph_acc2 -> graph_acc2
          {:value, _value} = value_vertex, graph_acc2 ->
            remove_value_from_other_components(graph_acc2, component_set, value_vertex, vars)
    end)
  end)
  end

  ## Remove value from variables that do not belong to the component
  defp remove_value_from_other_components(graph, component_set, {:value, value} = value_vertex, vars) do
    graph
    |> Graph.out_neighbors(value_vertex)
    |> Enum.reduce(graph, fn {:variable, id} = variable_vertex, graph_acc ->
      if MapSet.member?(component_set, variable_vertex) do
        ## The variable in the same component, do nothing
        graph_acc
       else
         remove(Propagator.arg_at(vars, id), value)
         Graph.delete_edge(graph_acc, value_vertex, variable_vertex)
       end
       ## Ignore to-sink edges
       :sink, graph_acc -> graph_acc
    end)
  end

  defp remove_empty_sccs(sccs) do

    Enum.reduce(sccs, [], fn
      ## Drop single-element components
      [_single], acc -> acc
       component, acc ->
        [component | acc]
    end)
  end

  defp fail() do
    throw(:fail)
  end

  alias CPSolver.IntVariable, as: Variable

  def test(domains) do
    vars =
      Enum.map(Enum.with_index(domains, 1), fn {d, idx} -> Variable.new(d, name: "x#{idx}") end)

    {:ok, vars, _store} = CPSolver.ConstraintStore.create_store(vars)

    initial_state(vars)
    |> tap(fn _ -> IO.inspect(Enum.map(vars, fn var -> {var.name, Interface.domain(var) |> Domain.to_list()} end)) end)
  end
end
