defmodule CPSolver.Propagator.ConstraintGraph do
  @moduledoc """
  The constraint graph connects propagators and their variables.
  The edge between a propagator and a variable represents a notification
  the propagator receives upon variable's domain change.
  The edge is labeled by the above notification type and 'arg_position' value that maps
  a variable to the position in propagator arguments.
  """
  alias CPSolver.Propagator
  alias CPSolver.Variable.Interface
  alias CPSolver.DefaultDomain, as: Domain

  @spec create([Propagator.t()] | %{reference() => Propagator.t()}) :: Graph.t()
  def create(propagators) when is_list(propagators) do
    propagators
    |> Enum.map(fn p -> {p.id, p} end)
    |> Map.new()
    |> create()
  end

  def create(propagators) when is_map(propagators) do
    Enum.reduce(propagators, Graph.new(), fn {propagator_id, p}, graph_acc ->
      add_propagator(graph_acc, propagator_id, p)
    end)
  end

  defp add_propagator(graph, propagator_id, propagator) do
    propagator
    |> Map.get(:args)
    |> Enum.with_index()
    |> Enum.reduce({graph, Map.new()}, fn {arg, pos}, {graph_acc, position_map_acc} ->
      if Propagator.is_constant_arg(arg) do
        {graph_acc, position_map_acc}
      else
        var_id = Interface.id(arg)

        {pos, position_map_acc} =
          case Map.get(position_map_acc, var_id) do
            nil ->
              {pos, Map.put(position_map_acc, var_id, pos)}

            existing ->
              {existing, position_map_acc}
          end

        ##
        {Graph.add_vertex(graph_acc, propagator_vertex(propagator_id))
         |> Graph.add_edge({:variable, var_id}, propagator_vertex(propagator_id),
           label: %{domain_change: get_propagate_on(arg), arg_position: pos}
         ), position_map_acc}
      end
    end)
    |> elem(0)
    |> Graph.label_vertex(propagator_vertex(propagator_id), propagator)
  end

  def get_propagator_ids(constraint_graph, variable_id, filter_fun)
      when is_function(filter_fun) do
    constraint_graph
    |> Graph.edges({:variable, variable_id})
    |> Enum.flat_map(fn edge ->
      if edge && filter_fun.(edge) do
        {:propagator, p_id} = edge.v2
        [{p_id, edge.label}]
      else
        []
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
      domain_change in edge.label.domain_change
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
      Enum.reduce(
        vars,
        {graph, [], Map.new()},
        fn %{domain: domain} = v, {graph_acc, propagators_acc, variables_acc} ->
          {if Domain.fixed?(domain) do
             remove_variable(graph_acc, Interface.id(v))
           else
             graph_acc
           end,
           propagators_acc ++
             (get_propagator_ids(graph_acc, Interface.id(v), fn _ -> true end)
              |> Enum.map(fn {p_id, _data} -> p_id end)),
           Map.put(variables_acc, Interface.id(v), v)}
        end
      )

    ## Update domains
    Enum.reduce(propagators, {g1, []}, fn p_id, {graph_acc, p_acc} ->
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
