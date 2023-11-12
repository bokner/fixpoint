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
    |> Enum.map(fn p -> {p.id, p} end)
    |> Map.new()
    |> create()
  end

  def create(propagators) when is_map(propagators) do
    Enum.reduce(propagators, Graph.new(), fn {propagator_id, %{mod: propagator_mod, args: args}} =
                                               propagator,
                                             acc ->
      args
      |> propagator_mod.variables()
      |> Enum.reduce(acc, fn var, acc2 ->
        Graph.add_vertex(acc2, {:propagator, propagator_id})
        |> Graph.add_edge({:variable, var.id}, {:propagator, propagator_id},
          label: get_propagate_on(var)
        )
      end)
      |> Graph.label_vertex({:propagator, propagator_id}, propagator)
    end)
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
         Graph.vertex_labels(constraint_graph, edge.v2)) ||
        []
    end)
  end

  def get_propagator(%Graph{} = graph, propagator_id) do
    Graph.vertex_labels(graph, {:propagator, propagator_id}) |> hd
  end

  def remove_propagator(table_or_graph, propagator_id) do
    remove_vertex(table_or_graph, {:propagator, propagator_id})
  end

  def remove_variable(table_or_graph, variable_id) do
    remove_vertex(table_or_graph, {:variable, variable_id})
  end

  def remove_vertex(graph, vertex) do
    Graph.delete_vertex(graph, vertex)
  end

  defp get_propagate_on(%Variable{} = variable) do
    Map.get(variable, :propagate_on, Propagator.to_domain_events(:fixed))
  end
end
