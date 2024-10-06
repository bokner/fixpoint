defmodule CPSolver.Propagator.AllDifferent.DC do
  use CPSolver.Propagator

  alias CPSolver.Algorithms.Kuhn

  @moduledoc """
  The domain-consistent propagator for AllDifferent constraint,
  based on bipartite maximum matching.
  """

  ## TODO: make private
  def initial_state(vars) do
    {value_graph, variable_indices, partial_matching} = build_value_graph(vars)
    maximum_matching = compute_maximum_matching(value_graph, variable_indices, partial_matching)
    #length(maximum_matching) < Arrays.size(vars) && fail()
    #|| %{value_graph: value_graph, maximum_matching: maximum_matching}

  end

  def build_value_graph(vars) do
    Enum.reduce(Enum.with_index(vars), {Graph.new(), [], Map.new()},
      fn {var, idx}, {graph_acc, var_ids_acc, partial_matching_acc} ->
        var_vertex = {:variable, idx}
        ## If the variable fixed, it's already in matching.
        ## We do not have to add it to the value graph.
        if fixed?(var) do
          {graph_acc, var_ids_acc, Map.put(partial_matching_acc, {:value, min(var)}, var_vertex)}
        else
          domain = domain(var) |> Domain.to_list()
          {Enum.reduce(domain, graph_acc, fn d, graph_acc2 ->
            Graph.add_edge(graph_acc2, var_vertex, {:value, d})
          end), [var_vertex | var_ids_acc], partial_matching_acc}
        end
      end)
  end

  defp compute_maximum_matching(value_graph, variable_ids, partial_matching) do
    Kuhn.run(value_graph, variable_ids, partial_matching)
  end

  @impl true
  def variables(args) do
    Enum.map(args, fn x_el -> set_propagate_on(x_el, :domain_change) end)
  end

  @impl true
  def filter(args, nil, changes) do
    filter(args, initial_state(args), changes)
  end

  @impl true
  def filter(all_vars, %{unfixed_ids: []} = _state, _changes) do
    :passive
  end

  def filter(all_vars, %{unfixed_ids: unfixed_ids} = _state, _changes) do
    state = filter_impl(all_vars, unfixed_ids)
    {:state, state}
  end

  defp filter_impl(all_vars, unfixed_vars) do
    :todo
  end




  defp fail() do
    throw(:fail)
  end

  alias CPSolver.IntVariable, as: Variable

  def test(domains) do
    vars = Enum.map(Enum.with_index(domains,1), fn {d, idx} -> Variable.new(d, name: "x#{idx}") end)
    {:ok, vars, store} = CPSolver.ConstraintStore.create_store(vars)

    initial_state(vars)
  end
end
