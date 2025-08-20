defmodule CPSolver.Propagator.ConstraintGraph do
  @moduledoc """
  The constraint graph connects propagators and their variables.
  The edge between a propagator and a variable represents a notification
  the propagator receives upon variable's domain change.
  """
  alias CPSolver.Propagator
  alias CPSolver.Variable.Interface
  
  require Logger

  @spec create([Propagator.t()]) :: Graph.t()
  def create(propagators) when is_list(propagators) do
    Enum.reduce(propagators, Graph.new(), fn p, graph_acc ->
      add_propagator(graph_acc, p)
    end)
  end

  def copy(%Graph{} = graph) do
    graph
  end

  def get_propagators(constraint_graph) do
    constraint_graph
    |> vertices()
    ## Get %{id => propagator} map
    |> Enum.flat_map(fn
      {:propagator, p_id} ->
        [get_propagator(constraint_graph, p_id)]

      _ ->
        []
    end)
  end

  ## Get a list of propagator ids for variable id
  def get_propagator_ids(constraint_graph, variable_id) do
    edges(constraint_graph, variable_vertex(variable_id))
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
      )
      when is_atom(domain_change) do
    propagators_by_variable(constraint_graph, variable_id, fn p_id, propagator_variable_edge ->
      domain_change in propagator_variable_edge.propagate_on &&
        get_propagator_data(
          propagator_variable_edge,
          domain_change,
          get_propagator(constraint_graph, p_id)
        )
    end)
  end

  def vertices(%Graph{} = constraint_graph) do
    Graph.vertices(constraint_graph)
  end

  def edges(%Graph{} = graph) do
    Graph.edges(graph)
  end

  def edges(%Graph{} = constraint_graph, vertex) do
    Graph.edges(constraint_graph, vertex)
  end

  def add_vertex(%Graph{} = graph, vertex, label) do
    Graph.add_vertex(graph, vertex, label)
  end

  def add_edge(%Graph{} = graph, from, to, label) do
    Graph.add_edge(graph, from, to, label: label)
  end

  defp propagators_by_variable(constraint_graph, variable_id, reduce_fun)
       when is_function(reduce_fun, 2) do
    constraint_graph
    |> edges(variable_vertex(variable_id))
    |> Enum.reduce(Map.new(), fn edge, acc ->
      {:propagator, p_id} = edge.v2

      ((p_data = reduce_fun.(p_id, edge.label)) && p_data && Map.put(acc, p_id, p_data)) ||
        acc
    end)
  end

  defp get_propagator_data(_edge, domain_change, propagator) do
    %{
      domain_change: domain_change,
      propagator: propagator
    }
  end

  def add_variable(graph, variable) do
    add_vertex(graph, variable_vertex(variable.id), [variable])
  end

  def add_propagator(graph, propagator) do
      add_propagator_impl(graph, propagator)
  end

  defp add_propagator_impl(graph, propagator) do
    propagator_vertex = propagator_vertex(propagator.id)

    propagator
    |> Propagator.variables()
    |> Enum.reduce(graph, fn var, graph_acc ->
      interface_var = Interface.variable(var)

      graph_acc
      |> add_variable(interface_var)
      |> add_vertex(propagator_vertex, propagator)
      |> then(fn graph ->
        (Interface.fixed?(interface_var) && graph) ||
          add_edge(graph, variable_vertex(interface_var.id), propagator_vertex,
            %{
              propagate_on: get_propagate_on(var)
            }
          )
      end)
    end)
  end

  def get_propagator(graph, {:propagator, _propagator_id} = vertex) do
    get_label(graph, vertex)
    |> tap(fn ps ->
      is_list(ps) &&
        Logger.error(
          inspect(
            {"Multiple propagators", vertex, Enum.map(ps, fn p -> Map.take(p, [:id, :mod]) end)}
          )
        )
    end)
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

    if propagator.id != elem(vertex, 1) do
      Logger.error("""
      Mismatch between propagator id and CG vertex
      Propagator id: #{propagator.id}"
      Propagator vertex: #{inspect(vertex)}
      """)

      graph
    else
      graph
      |> Map.put(:vertex_labels, Map.put(labels, identifier.(vertex), propagator))
    end
  end

  def variable_vertex(variable_id) do
    {:variable, variable_id}
  end

  def propagator_vertex(propagator_id) do
    {:propagator, propagator_id}
  end

  def variable_degree(graph, variable_id) do
    out_degree(graph, variable_vertex(variable_id))
  end

  def propagator_degree(graph, propagator_id) do
    in_degree(graph, propagator_vertex(propagator_id))
  end

  def remove_propagator(graph, propagator_id) do
    remove_vertex(graph, propagator_vertex(propagator_id))
  end

  def entailed_propagator?(graph, propagator) do
    Enum.empty?(in_neighbors(graph, propagator_vertex(propagator.id)))
  end

  def get_variable(graph, {:variable, _variable_id} = vertex) do
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
    delete_edges(graph, edges(graph, variable_vertex(variable_id)))
  end

  def disconnect_propagator(graph, propagator_id) do
    delete_edges(graph, edges(graph, propagator_vertex(propagator_id)))
  end

  ### This is called on creation of new space.
  ###
  ### Stop notifications from fixed variables and update propagators with variable domains.
  ### Returns updated graph and a list of propagators bound to variable domains
  def update(graph, vars) do
    Enum.reduce(vars, graph, fn v, graph_acc ->
      update_variable(graph_acc, v)
    end)
  end

  def remove_vertex(graph, vertex) do
    delete_vertex(graph, vertex)
  end

  defp get_propagate_on(variable) do
    Map.get(variable, :propagate_on) || Propagator.to_domain_events(:fixed)
  end

  defp get_label(%Graph{} = graph, vertex) do
    case Graph.vertex_labels(graph, vertex) do
      [] -> nil
      [p] -> p
      p -> p
    end
  end

  defp in_degree(%Graph{} = graph, vertex) do
    Graph.in_degree(graph, vertex)
  end

  defp out_degree(%Graph{} = graph, vertex) do
    Graph.out_degree(graph, vertex)
  end

  defp in_neighbors(%Graph{} = graph, vertex) do
    Graph.in_neighbors(graph, vertex)
  end

  def update_variable(
        %Graph{vertex_labels: labels, vertex_identifier: identifier} = graph,
        variable
      ) do
    vertex = variable_vertex(Interface.id(variable))

    Map.put(graph, :vertex_labels, Map.put(labels, identifier.(vertex), variable))
    #graph
  end

  defp delete_vertex(%Graph{} = graph, vertex) do
    Graph.delete_vertex(graph, vertex)
  end

  defp delete_edges(%Graph{} = graph, edges) do
    Graph.delete_edges(graph, edges)
  end
end
