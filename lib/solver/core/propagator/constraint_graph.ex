defmodule CPSolver.Propagator.ConstraintGraph do
  @moduledoc """
  The constraint graph connects propagators and their variables.
  The edge between a propagator and a variable represents a notification
  the propagator receives upon variable's domain change.
  """
  alias CPSolver.Propagator
  alias CPSolver.Variable.Interface
  alias CPSolver.DefaultDomain, as: Domain

  @spec create([Propagator.t()]) :: Graph.t()
  def create(propagators) when is_list(propagators) do
    Enum.reduce(propagators, Graph.new(), fn p, graph_acc ->
      add_propagator(graph_acc, p)
    end)
  end

  def get_propagator_ids(constraint_graph, variable_id, filter_fun)
      when is_function(filter_fun) do
    constraint_graph
    |> Graph.edges({:variable, variable_id})
    |> Enum.reduce(Map.new(), fn edge, acc ->
      if filter_fun.(edge) do
        {:propagator, p_id} = edge.v2
        Map.put(acc, p_id, edge.label)
      else
        acc
      end
    end)
  end

  ## Get a list of propagator ids that "listen" to the domain change of given variable.
  def get_propagator_ids(
        constraint_graph,
        variable_id,
        domain_change
      ) do
    get_propagator_ids(constraint_graph, variable_id, fn edge ->
      domain_change in edge.label.propagate_on
    end)
  end

  def has_variable?(graph, variable_id) do
    Graph.has_vertex?(graph, {:variable, variable_id})
  end

  def add_propagator(graph, propagator) do
    propagator_vertex = propagator_vertex(propagator.id)

    propagator
    |> Propagator.variables()
    |> Enum.reduce(graph, fn var, graph_acc ->
      Graph.add_vertex(graph_acc, propagator_vertex)
      |> Graph.add_edge({:variable, Interface.id(var)}, propagator_vertex,
        label: %{propagate_on: get_propagate_on(var), arg_position: var.arg_position}
      )
    end)
    |> Graph.label_vertex(propagator_vertex, propagator)
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

  ### Remove fixed variables and update propagators with variable domains.
  ### Returns updated graph and a list of propagators bound to variable domains
  def update(graph, vars) do
    ## Remove fixed variables
    {g1, propagators, variable_map} =
      Enum.reduce(vars, {graph, [], Map.new()}, fn %{domain: domain} = v,
                                                   {graph_acc, propagators_acc, variables_acc} ->
        {if Domain.fixed?(domain) do
           remove_variable(graph_acc, Interface.id(v))
         else
           graph_acc
         end,
         propagators_acc ++
           Map.keys(get_propagator_ids(graph_acc, Interface.id(v), fn _ -> true end)),
         Map.put(variables_acc, Interface.id(v), v)}
      end)

    ## Update domains
    List.foldr(propagators, {g1, []}, fn p_id, {graph_acc, p_acc} ->
      get_propagator(graph_acc, p_id)
      |> Propagator.bind_to_variables(variable_map, :domain)
      |> then(fn bound_p ->
        {
          update_propagator(graph_acc, p_id, bound_p),
          [bound_p | p_acc]
        }
      end)
    end)
  end

  def remove_vertex(graph, vertex) do
    Graph.delete_vertex(graph, vertex)
  end

  defp get_propagate_on(variable) do
    Map.get(variable, :propagate_on) || Propagator.to_domain_events(:fixed)
  end
end
