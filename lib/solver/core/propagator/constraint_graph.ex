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

  def propagators_by_variable(constraint_graph, variable_id, reduce_fun)
      when is_function(reduce_fun, 2) do
    constraint_graph
    |> Graph.edges(variable_vertex(variable_id))
    |> Enum.reduce(Map.new(), fn edge, acc ->
      {:propagator, p_id} = edge.v2

      ((p_data = reduce_fun.(p_id, edge.label)) && p_data && Map.put(acc, p_id, p_data)) ||
        acc
    end)
  end

  ## Get a list of propagator ids that "listen" to the domain change of given variable.
  def propagators_by_variable(
        constraint_graph,
        variable_id,
        domain_change
      ) do
    propagators_by_variable(constraint_graph, variable_id, fn p_id, propagator_variable_edge ->
      domain_change in propagator_variable_edge.propagate_on &&
        get_propagator_data(
          propagator_variable_edge,
          domain_change,
          get_propagator(constraint_graph, p_id)
        )
    end)
  end

  defp get_propagator_data(edge, domain_change, propagator) do
    %{arg_position: edge.arg_position, domain_change: domain_change, propagator: propagator}
  end

  def has_variable?(graph, variable_id) do
    Graph.has_vertex?(graph, variable_vertex(variable_id))
  end

  def add_propagator(graph, propagator) do
    propagator_vertex = propagator_vertex(propagator.id)

    propagator
    |> Propagator.variables()
    |> Enum.reduce(graph, fn var, graph_acc ->
      Graph.add_vertex(graph_acc, propagator_vertex)
      |> Graph.add_edge(variable_vertex(Interface.id(var)), propagator_vertex,
        label: %{propagate_on: get_propagate_on(var), arg_position: var.arg_position}
      )
    end)
    |> Graph.label_vertex(propagator_vertex, propagator)
  end

  def get_propagator(%Graph{} = graph, {:propagator, _propagator_id} = vertex) do
    case Graph.vertex_labels(graph, vertex) do
      [] -> nil
      [p] -> p
    end
  end

  def get_propagator(graph, propagator_id) do
    get_propagator(graph, propagator_vertex(propagator_id))
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

  def variable_vertex(variable_id) do
    {:variable, variable_id}
  end

  def propagator_vertex(propagator_id) do
    {:propagator, propagator_id}
  end

  def remove_propagator(graph, propagator_id) do
    remove_vertex(graph, propagator_vertex(propagator_id))
  end

  def remove_edge(graph, var_id, propagator_id) do
    Graph.delete_edge(graph, variable_vertex(var_id), propagator_vertex(propagator_id))
  end

  def entailed_propagator?(graph, propagator) do
    Enum.empty?(Graph.neighbors(graph, propagator_vertex(propagator.id)))
  end

  ## Remove variable and all propagators that are isolated points as a result of variable removal
  def remove_variable(graph, variable_id) do
    remove_vertex(graph, variable_vertex(variable_id))
  end

  ### Remove fixed variables and update propagators with variable domains.
  ### Returns updated graph and a list of propagators bound to variable domains
  def update(graph, vars) do
    ## Remove fixed variables
    {g1, propagators, variable_map} =
      Enum.reduce(vars, {graph, [], Map.new()}, fn %{domain: domain} = v,
                                                   {graph_acc, propagators_acc, variables_acc} ->
        {if Domain.fixed?(domain) do

            #remove_variable(graph_acc, Interface.id(v))
            graph_acc
         else
           graph_acc
         end,
         propagators_acc ++
           Map.keys(
             propagators_by_variable(graph_acc, Interface.id(v), fn _p_id, edge -> edge end)
           ), Map.put(variables_acc, Interface.id(v), v)}
      end)

    ## Update domains
    propagators
    |> Enum.uniq()
    |> List.foldr({g1, []}, fn p_id, {graph_acc, p_acc} ->
      graph_acc
      |> get_propagator(p_id)
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
