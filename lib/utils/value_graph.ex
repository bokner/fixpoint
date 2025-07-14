defmodule CPSolver.ValueGraph do
  alias CPSolver.Utils
  alias CPSolver.Variable.Interface
  alias CPSolver.Propagator
  alias CPSolver.Propagator.Variable, as: PropagatorVariable

  def build(variables, opts \\ []) do
    ## Builds value graph and supporting structures
    ## that may be used further (for instance, by Kuhn algorithm).
    ## Value graph is bipartite.
    ## Value graph edges are {:variable, id} -> {:value, value}
    ##
    ## Fixed matching is a map {:variable, id} => {:value, value}
    ## , where variable is fixed.
    ## The set of {:variable, id} elements is a "variable" partition of value graph,
    ## that is, vertices that represent variables.
    ## Optional:
    ## :check_matching (false by default) - fails if there is no perfect matching
    ## that is, some variables fixed to the same value.
    ## Note: we do not explicitly add edges, they will be derived through
    ## BitGraph's `neighbor_finder` function based on current variables' domain values.
    ##
    check_matching? = Keyword.get(opts, :check_matching, false)
    ignore_fixed_variables? = Keyword.get(opts, :ignore_fixed_variables, false)

    {value_vertices, var_count, fixed, fixed_values} =
      Enum.reduce(
        variables,
        {MapSet.new(), 0, Map.new(), MapSet.new()},
        fn var,
           {
             vertices_acc,
             var_count_acc,
             fixed_matching_acc,
             fixed_values_acc
           } ->
          domain = Utils.domain_values(var)
          domain_size = MapSet.size(domain)

          vertices_acc =
            Enum.reduce(domain, vertices_acc, fn value, acc ->
              MapSet.put(acc, {:value, value})
            end)

          {fixed_matching_acc, fixed_values_acc} =
            if domain_size == 1 do
              fixed_value = Enum.fetch!(domain, 0)
              MapSet.member?(fixed_values_acc, fixed_value) && check_matching? && fail()

              {
                Map.put(fixed_matching_acc, {:variable, var_count_acc}, {:value, fixed_value}),
                MapSet.put(fixed_values_acc, fixed_value)
              }
            else
              {fixed_matching_acc, fixed_values_acc}
            end

          {vertices_acc, var_count_acc + 1, fixed_matching_acc, fixed_values_acc}
        end
      )

    left_partition =
      Enum.reduce(0..(var_count - 1), MapSet.new(), fn idx, acc ->
        variable_vertex = {:variable, idx}

        (ignore_fixed_variables? && Map.has_key?(fixed, variable_vertex) && acc) ||
          MapSet.put(acc, variable_vertex)
      end)

    value_vertices =
      (ignore_fixed_variables? &&
         MapSet.reject(value_vertices, fn {:value, value} -> value in fixed_values end)) ||
        value_vertices

    %{
      value_graph:
        BitGraph.new(
          max_vertices: MapSet.size(value_vertices) + var_count,
          neighbor_finder: default_neighbor_finder(variables),
          variable_count: var_count
        )
        |> BitGraph.add_vertices(left_partition)
        |> BitGraph.add_vertices(value_vertices),
      left_partition: left_partition,
      fixed_matching: fixed,
      fixed_values: fixed_values
    }
  end

  ## Forward checking (cascading removal of fixed variables).
  ## Note: value graph with default neighbor finder
  ## has edges oriented from variables to values.
  ## The result of forward checking will be a value graph with
  ## removed fixed variable vertices, and the side effect will be
  ## a domain reduction such that no domain value is shared between fixed variables.
  def forward_checking(graph, fixed_vertices, variables) do
    {updated_graph, _, newly_fixed_vertices} = forward_checking_impl(graph, fixed_vertices, variables)
    %{value_graph: updated_graph, new_fixed: newly_fixed_vertices}
  end

  defp forward_checking_impl(graph, fixed_vertices, variables) do
    forward_checking_impl(graph, fixed_vertices, variables, MapSet.new())
  end

  defp forward_checking_impl(graph, fixed_vertices, variables, newly_fixed) do
    for var_vertex <- fixed_vertices, reduce: {graph, MapSet.new(), newly_fixed} do
      {graph_acc, fixed_acc, newly_fixed_acc} = _acc ->
        value_vertex = BitGraph.out_neighbors(graph, var_vertex) |> MapSet.to_list() |> hd
        graph = BitGraph.delete_vertex(graph_acc, var_vertex)

        {updated_graph, new_fixed_vertices} =
          Enum.reduce(BitGraph.in_neighbors(graph, value_vertex), {graph, fixed_acc}, fn {:variable, var_index} =
                                                                            var_neighbor,
                                                                          {g_acc, f_acc} ->
            g_acc = delete_edge(g_acc, var_neighbor, value_vertex, variables)

            f_acc =
              PropagatorVariable.fixed?(get_variable(variables, var_index)) &&
                  MapSet.put(f_acc, var_neighbor) || f_acc

            {g_acc, f_acc}
          end)

        forward_checking_impl(
          BitGraph.delete_vertex(updated_graph, value_vertex), new_fixed_vertices, variables, MapSet.union(newly_fixed_acc, new_fixed_vertices))
    end
  end

  defp fail(reason \\ :fail) do
    throw(reason)
  end

  def get_variable_count(value_graph) do
    get_in(value_graph, [:opts, :variable_count])
  end

  def default_neighbor_finder(variables) do
    fn graph, vertex_index, direction ->
      vertex = BitGraph.V.get_vertex(graph, vertex_index)
      (vertex && get_neighbors(graph, vertex, variables, direction)) || MapSet.new()
    end
  end

  defp get_neighbors(_graph, {:variable, _var_index}, _variables, :in) do
    MapSet.new()
  end

  defp get_neighbors(_graph, {:value, _value}, _variables, :out) do
    MapSet.new()
  end

  defp get_neighbors(graph, {:variable, var_index}, variables, :out) do
    get_variable(variables, var_index)
    |> Utils.domain_values()
    |> Enum.reduce(MapSet.new(), fn value, acc ->
      MapSet.put(acc, BitGraph.V.get_vertex_index(graph, {:value, value}))
    end)
  end

  defp get_neighbors(graph, {:value, value}, variables, :in) do
    Enum.reduce(variables, {0, MapSet.new()}, fn var, {idx, n_acc} ->
      {idx + 1,
       (Interface.contains?(var, value) &&
          MapSet.put(n_acc, BitGraph.V.get_vertex_index(graph, {:variable, idx}))) || n_acc}
    end)
    |> elem(1)
  end

  defp get_neighbors(_graph, _additional_vertex, _variables, _direction) do
    MapSet.new()
  end

  ## Matching edges will be reversed
  def matching_neighbor_finder(graph, variables, matching, free_nodes) do
    default_neighbor_finder = default_neighbor_finder(variables)

    {indexed_matching, reversed_indexed_matching} =
      Enum.reduce(matching, {Map.new(), Map.new()}, fn {{:variable, var_index} = var_vertex,
                                                        {:value, value} = value_vertex},
                                                       {matching_acc, reverse_matching_acc} ->
        propagator_variable = get_variable(variables, var_index)

        Interface.contains?(propagator_variable, value) || MapSet.new()
        # fail({:invalid_matching, var_vertex, value_vertex})

        var_vertex_index = BitGraph.V.get_vertex_index(graph, var_vertex)
        value_vertex_index = BitGraph.V.get_vertex_index(graph, value_vertex)

        {
          Map.put(
            matching_acc,
            var_vertex_index,
            {value_vertex_index, propagator_variable, value, var_vertex}
          ),
          Map.put(
            reverse_matching_acc,
            value_vertex_index,
            {var_vertex_index, propagator_variable, value, var_vertex}
          )
        }
      end)

      free_nodes = MapSet.new(free_nodes, fn node -> BitGraph.V.get_vertex_index(graph, node) end)

    fn graph, vertex_index, direction ->
      neighbors = default_neighbor_finder.(graph, vertex_index, direction)
      #IO.inspect({vertex_index, neighbors, direction}, label: :original_neighbors)

      ## By construction, 'variable' vertex indices go first
      vertex_type =
        vertex_index <= get_variable_count(graph) && :variable ||
          :value

      adjust_neighbors(
        neighbors,
        vertex_index,
        vertex_type,
        indexed_matching,
        reversed_indexed_matching,
        free_nodes,
        direction
      )
    end
  end

  ## Out-neighbors
  ## If vertex is a 'variable', remove matched value from 'out' neighbors.
  ##
  ## If vertex is a 'value', make matched variable a single 'out' neighbor.
  ## Otherwise, keep neighbors as is.
  ##
  defp adjust_neighbors(
         neighbors,
         vertex_index,
         :variable,
         variable_matching,
         value_matching,
         free_nodes,
         :out
       ) do
    case Map.get(variable_matching, vertex_index) do
      nil ->
        MapSet.new()

      {value_match, _, _, _} ->
        ## Remove value from 'out' neighbors of variable vertex
        MapSet.delete(neighbors, value_match)
    end
    |> MapSet.filter(fn nbr -> Map.has_key?(value_matching, nbr) || nbr in free_nodes end)
  end

  defp adjust_neighbors(
         neighbors,
         vertex_index,
         :value,
         variable_matching,
         value_matching,
         _free_nodes,
         :out
       ) do
    case Map.get(value_matching, vertex_index) do
      nil ->
        neighbors

      {variable_match, variable, matching_value, _variable_vertex} ->
        ## matched value must be in the domain of matching variable
        (Interface.contains?(variable, matching_value) &&
           MapSet.new([variable_match])) || MapSet.new()
    end
    |> MapSet.filter(fn nbr -> Map.has_key?(variable_matching, nbr) end)
  end

  ## In-neighbors
  ## If vertex is a 'variable', make matched value a single 'in' neighbor.
  ##
  ## If vertex is a 'value', remove matched variable from 'in' neighbors.
  ##
  defp adjust_neighbors(_neighbors, vertex_index, :variable, variable_matching,
         _value_matching, _free_nodes, :in) do
    case Map.get(variable_matching, vertex_index) do
      nil ->
        MapSet.new()

      {value_match, variable, matching_value, _variable_vertex} ->
        (Interface.contains?(variable, matching_value) &&
           MapSet.new([value_match])) || MapSet.new()
    end
  end

  defp adjust_neighbors(neighbors, vertex_index, :value, variable_matching, value_matching, free_nodes, :in) do
    case Map.get(value_matching, vertex_index) do
      nil ->
        ## Nowhere in matching; could be a free node;
        ## otherwise it'd be part of excluded matching
        vertex_index in free_nodes && neighbors || MapSet.new()

      {variable_match, _, _, _} ->
        MapSet.delete(neighbors, variable_match)
    end
    |> MapSet.filter(fn nbr -> Map.has_key?(variable_matching, nbr) end)
  end

  def delete_edge(
        graph,
        {:value, _value} = value_vertex,
        {:variable, _var_index} = var_vertex,
        variables
      ) do
    delete_edge(graph, var_vertex, value_vertex, variables)
  end

  def delete_edge(graph, {:variable, var_index}, {:value, value} = value_vertex, variables) do
    propagator_variable = get_variable(variables, var_index)

    _change = PropagatorVariable.remove(propagator_variable, value)

    (BitGraph.degree(graph, value_vertex) == 0 &&
        BitGraph.delete_vertex(graph, value_vertex)) || graph
  end

  def get_variable(variables, var_index) do
    Propagator.arg_at(variables, var_index)
  end

  def show_graph_v1(graph, context \\ nil) do
    "context: " <> (context && inspect(context) || "") <> "\n"
    <> Enum.map_join(BitGraph.vertices(graph), "\n", fn vertex ->
      neighbors = BitGraph.out_neighbors(graph, vertex)
      Enum.empty?(neighbors) && "#{inspect vertex} []" ||
      (
      edges =  Enum.map_join(neighbors,
          ", ", fn neighbor -> "#{inspect neighbor}" end)
      "#{inspect vertex} -> [ #{edges} ]"
      )
    end)
    |> IO.puts()
  end

  def show_graph(graph, context \\ nil) do
    %{context: context,
      edges:
    BitGraph.E.edges(graph) |> Enum.map(fn %{from: from_index, to: to_index} ->
      {
        BitGraph.V.get_vertex(graph, from_index),
        BitGraph.V.get_vertex(graph, to_index)
      }
    end)
    |> Enum.group_by(fn {from, _to} -> from end, fn {_from, to} -> to end)
    }
  end


end
