defmodule CPSolver.Propagator.ConstraintGraph do
  @moduledoc """
  The constraint graph connects propagators and their variables.
  The edge between a propagator and a variable represents a notification
  the propagator receives upon varable's domain change.
  """
  alias CPSolver.Propagator
  alias CPSolver.Variable.Interface

  @spec create([Propagator.t()] | %{reference() => Propagator.t()}) :: Graph.t()
  def create(propagators) when is_list(propagators) do
    propagators
    |> Enum.map(fn p -> {p.id, p} end)
    |> Map.new()
    |> create()
  end

  def create(propagators) when is_map(propagators) do
    Enum.reduce(propagators, Graph.new(), fn {propagator_id,
                                              %{mod: propagator_mod, args: args} = p},
                                             acc ->
      args
      |> propagator_mod.variables()
      |> Enum.reduce(acc, fn var, acc2 ->
        Graph.add_vertex(acc2, propagator_vertex(propagator_id))
        |> Graph.add_edge({:variable, Interface.id(var)}, propagator_vertex(propagator_id),
          label: get_propagate_on(var)
        )
      end)
      |> Graph.label_vertex(propagator_vertex(propagator_id), p)
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
      if domain_change in edge.label do
        {:propagator, p_id} = edge.v2
        [p_id]
      else
        []
      end
    end)
  end

  def has_variable?(graph, variable_id) do
    Graph.has_vertex?(graph, {:variable, variable_id})
  end

  def get_propagator(%Graph{} = graph, propagator_id) do
    case Graph.vertex_labels(graph, propagator_vertex(propagator_id)) do
      [] -> nil
      [p] -> p
    end
  end

  def update_propagator(
        %Graph{vertex_labels: labels, vertex_identifier: identifier} = graph,
        propagator_id,
        propagator
      ) do
    vertex = propagator_vertex(propagator_id)

    graph
    # |> Graph.remove_vertex_labels(vertex)
    # |> Graph.label_vertex(vertex, [propagator])
    |> Map.put(:vertex_labels, Map.put(labels, identifier.(vertex), [propagator]))
  end

  def propagator_vertex(propagator_id) do
    {:propagator, propagator_id}
  end

  def remove_propagator(graph, propagator_id) do
    remove_vertex(graph, propagator_vertex(propagator_id))
  end

  ## Remove variable and all propagators that are isolated points as a result of variable removal
  def remove_variable(graph, variable_id) do
    remove_vertex(graph, {:variable, variable_id})
  end

  def remove_fixed(graph, vars) do
    Enum.reduce(vars, graph, fn v, acc ->
      if Interface.fixed?(v) do
        remove_variable(acc, v.id)
      else
        acc
      end
    end)
  end

  def remove_vertex(graph, vertex) do
    Graph.delete_vertex(graph, vertex)
  end

  defp get_propagate_on(variable) do
    Map.get(variable, :propagate_on, Propagator.to_domain_events(:fixed))
  end
end
