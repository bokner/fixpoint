defmodule CPSolver.Propagator.ConstraintGraph do
  @moduledoc """
  The constraint graph connects propagators and their variables.
  The edge between a propagator and a variable represents a notification
  the propagator receives upon varable's domain change.
  """
  alias CPSolver.Propagator
  alias CPSolver.Variable

  @spec create([Propagator.t()] | %{reference() => Propagator.t()}) :: Graph.t()
  def create(propagators) when is_list(propagators) do
    propagators
    |> Enum.map(fn p -> {make_ref(), p} end)
    |> Map.new()
    |> create()
  end

  def create(propagators) when is_map(propagators) do
    Enum.reduce(propagators, Graph.new(), fn {propagator_id, {propagator_mod, args}} = _propagator,
                                             acc ->
      args
      |> propagator_mod.variables()
      |> Enum.reduce(acc, fn var, acc2 ->
        Graph.add_edge(acc2, {:variable, var.id}, {:propagator, propagator_id},
          label: get_propagate_on(var)
        )
      end)
    end)
  end

  def get_propagators(graph_table, variable_id, domain_change) when is_reference(graph_table) do
    graph_table
    |> read_graph()
    |> get_propagators(variable_id, domain_change)
  end

  ## Get a list of propagator ids that "listen" to the domain change of given variable.
  def get_propagators(
        constraint_graph,
        variable_id,
        domain_change
      ) do
    constraint_graph
    |> Graph.edges({:variable, variable_id})
    |> Enum.flat_map(fn edge ->
      (domain_change in edge.label &&
         [edge.v2 |> elem(1)]) || []
    end)
  end

  def remove_propagator(table_or_graph, propagator_id) do
    remove_vertex(table_or_graph, {:propagator, propagator_id})
  end

  def remove_variable(table_or_graph, variable_id) do
    remove_vertex(table_or_graph, {:variable, variable_id})
  end

  def remove_vertex(graph_table, vertex) when is_reference(graph_table) do
    graph_table
    |> read_graph()
    |> remove_vertex(vertex)
    |> update_graph(graph_table)
  end

  def remove_vertex(graph, vertex) do
    Graph.delete_vertex(graph, vertex)
  end

  def read_graph(graph_table) do
    [{:constraint_graph, graph}] = :ets.lookup(graph_table, :constraint_graph)
    graph
  end

  def update_graph(graph, graph_table) when is_reference(graph_table) do
    :ets.insert(graph_table, {:constraint_graph, graph})
  end

  defp get_propagate_on(%Variable{} = variable) do
    Map.get(variable, :propagate_on, Propagator.to_domain_events(:fixed))
  end
end
