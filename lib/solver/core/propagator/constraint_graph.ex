defmodule CPSolver.Propagator.ConstraintGraph do
  @moduledoc """
  The constraint graph connects propagators and their variables.
  The edge between a propagator and a variable represents a notification
  the propagator receives upon varable's domain change.
  """
  alias CPSolver.Propagator
  alias CPSolver.Propagator.Variable

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
        Graph.add_vertex(acc2, {:propagator, propagator_id})
        |> Graph.add_edge({:variable, var.id}, {:propagator, propagator_id},
          label: get_propagate_on(var)
        )
      end)
      |> Graph.label_vertex({:propagator, propagator_id}, p)
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

  def has_variable?(graph, variable_id) do
    Graph.has_vertex?(graph, {:variable, variable_id})
  end
  def get_propagator(%Graph{} = graph, propagator_id) do
    case Graph.vertex_labels(graph, {:propagator, propagator_id}) do
      [] -> nil
      [p] -> p
    end
  end

  def remove_propagator(graph, propagator_id) do
    remove_vertex(graph, {:propagator, propagator_id})
  end

  ## Remove variable and all propagators that are isolated points as a result of variable removal
  def remove_variable(graph, variable_id) do
    var_vertex = {:variable, variable_id}
    var_propagators = Graph.neighbors(graph, var_vertex)

    graph
    |> remove_vertex(var_vertex)
    |> then(fn g ->
      Enum.reduce(var_propagators, g, fn p_vertex, acc ->
        (Graph.neighbors(acc, p_vertex) == [] && Graph.delete_vertex(acc, p_vertex)) ||
          fix_propagator_variable(acc, p_vertex, variable_id)
      end)
    end)
  end

  defp fix_propagator_variable(graph, p_vertex, variable_id) do
    graph
    |> Graph.vertex_labels(p_vertex)
    |> hd
    |> Map.update(:args, %{}, fn args ->
      Enum.map(
        args,
        fn
          %{id: id} = arg when id == variable_id ->
            Map.put(arg, :fixed?, true)

          other ->
            other
        end
      )
    end)
    |> then(fn updated_propagator ->
      graph
      |> Graph.remove_vertex_labels(p_vertex)
      |> Graph.label_vertex(p_vertex, updated_propagator)
    end)
  end

  def remove_fixed(graph, vars) do
    Enum.reduce(vars, graph, fn v, acc ->
      if Variable.fixed?(v) do
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
