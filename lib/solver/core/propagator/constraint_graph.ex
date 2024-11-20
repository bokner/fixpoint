defmodule CPSolver.Propagator.ConstraintGraph do
  @moduledoc """
  The constraint graph connects propagators and their variables.
  The edge between a propagator and a variable represents a notification
  the propagator receives upon variable's domain change.
  """
  alias CPSolver.Propagator
  alias CPSolver.Variable.Interface

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

  ## Get a list of propagator ids for variable id
  def get_propagator_ids(constraint_graph, variable_id) do
    Graph.edges(constraint_graph, variable_vertex(variable_id))
    |> Enum.flat_map(fn
      %{v2: {:propagator, p_id}} = _edge ->
        [p_id]

      _ ->
        []
    end)
  end

  ## Get a list of propagator ids that "listen" to the domain change of given variable.
  def get_propagator_ids(
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

  defp get_propagator_data(_edge, domain_change, propagator) do
    %{
      domain_change: domain_change,
      propagator: propagator
    }
  end

  def has_variable?(graph, variable_id) do
    Graph.has_vertex?(graph, variable_vertex(variable_id))
  end

  def add_variable(graph, variable) do
    Graph.add_vertex(graph, variable_vertex(variable.id), [variable])
  end

  def add_propagator(graph, propagator) do
    propagator_vertex = propagator_vertex(propagator.id)

    propagator
    |> Propagator.variables()
    |> Enum.reduce(graph, fn var, graph_acc ->
      interface_var = Interface.variable(var)

      graph_acc
      |> add_variable(interface_var)
      |> Graph.add_vertex(propagator_vertex)
      |> then(fn graph ->
        (Interface.fixed?(interface_var) && graph) ||
          Graph.add_edge(graph, variable_vertex(interface_var.id), propagator_vertex,
            label: %{
              propagate_on: get_propagate_on(var),
              variable_name: interface_var.name
            }
          )
      end)
    end)
    |> Graph.label_vertex(propagator_vertex, propagator)
  end

  def get_propagator(%Graph{} = graph, {:propagator, _propagator_id} = vertex) do
    get_label(graph, vertex)
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

  def variable_degree(%Graph{} = graph, variable_id) do
    Graph.out_degree(graph, variable_vertex(variable_id))
  end

  def propagator_degree(%Graph{} = graph, propagator_id) do
    Graph.in_degree(graph, propagator_vertex(propagator_id))
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

  def get_variable(%Graph{} = graph, {:variable, _variable_id} = vertex) do
    get_label(graph, vertex)
  end

  def get_variable(graph, variable_id) do
    get_variable(graph, variable_vertex(variable_id))
  end

  ## Remove variable
  def remove_variable(graph, variable_id) do
    remove_vertex(graph, variable_vertex(variable_id))
  end

  def disconnect_variable(graph, variable_id) do
    Graph.delete_edges(graph, Graph.edges(graph, variable_vertex(variable_id)))
  end

  ### This is called on creation of new space.
  ###
  ### Stop notifications from fixed variables and update propagators with variable domains.
  ### Returns updated graph and a list of propagators bound to variable domains
  def update(graph, vars) do
    {updated_var_graph, propagators} =
      Enum.reduce(vars, {graph, MapSet.new()}, fn %{id: var_id} = v,
                                                  {graph_acc, propagators_acc} ->
        {update_variable(graph_acc, var_id, v),
         MapSet.union(
           propagators_acc,
           MapSet.new(
             Map.keys(propagators_by_variable(graph, Interface.id(v), fn _p_id, edge -> edge end))
           )
         )}
      end)

    ## Update domains
    propagators
    |> Enum.reduce({updated_var_graph, []}, fn p_id, {graph_acc, p_acc} ->
      graph_acc
      |> get_propagator(p_id)
      |> Propagator.bind(updated_var_graph, :domain)
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

  defp get_label(%Graph{} = graph, vertex) do
    case Graph.vertex_labels(graph, vertex) do
      [] -> nil
      [p] -> p
    end
  end

  def update_variable(
        %Graph{vertex_labels: labels, vertex_identifier: identifier} = graph,
        var_id,
        variable
      ) do
    vertex = variable_vertex(var_id)

    Map.put(graph, :vertex_labels, Map.put(labels, identifier.(vertex), [variable]))
  end
end
