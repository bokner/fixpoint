defmodule CPSolver.ValueGraph do
  alias CPSolver.Utils
  alias CPSolver.Variable.Interface
  alias CPSolver.Propagator
  alias CPSolver.Propagator.Variable, as: PropagatorVariable
  alias Iter.Iterable.{Empty, Mapper, FlatMapper, Filterer}

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
          allocate_adjacency_table?: false,
          neighbor_finder: default_neighbor_finder(variables),
          variable_count: var_count
        )
        |> BitGraph.add_vertices(left_partition)
        |> BitGraph.add_vertices(value_vertices),
      left_partition: left_partition,
      fixed_matching: fixed,
      fixed_values: fixed_values,
      unfixed_indices: Enum.reduce(left_partition,
        MapSet.new(), fn {:variable, idx}, acc ->
          Map.has_key?(fixed, {:variable, idx}) && acc || MapSet.put(acc, idx) end)
    }
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
      (vertex && get_neighbors(graph, vertex, variables, direction)) || Empty.new()
    end
  end

  defp get_neighbors(_graph, {:variable, _var_index}, _variables, :in) do
    Empty.new()
  end

  defp get_neighbors(_graph, {:value, _value}, _variables, :out) do
    Empty.new()
  end

  defp get_neighbors(graph, {:variable, var_index}, variables, :out) do
    get_variable(variables, var_index)
    |> Interface.iterator()
    |> Mapper.new(fn value ->
      BitGraph.V.get_vertex_index(graph, {:value, value})
    end)
  end

  defp get_neighbors(graph, {:value, value}, variables, :in) do
      FlatMapper.new(0..get_variable_count(graph) - 1,
          fn idx ->
            Interface.contains?(get_variable(variables, idx), value) &&
            [BitGraph.V.get_vertex_index(graph, {:variable, idx})] || []
          end
        )
  end

  defp get_neighbors(_graph, _additional_vertex, _variables, _direction) do
    Empty.new()
  end

  ## Matching edges will be reversed
  def matching_neighbor_finder(graph, variables, matching, _free_nodes) do
    neighbor_finder = default_neighbor_finder(variables)

    {indexed_matching, reversed_indexed_matching} =
      Enum.reduce(matching, {Map.new(), Map.new()}, fn {{:variable, var_index} = var_vertex,
                                                        {:value, value} = value_vertex},
                                                       {matching_acc, reverse_matching_acc} ->
        propagator_variable = get_variable(variables, var_index)

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

    fn graph, vertex_index, direction ->
      ## By construction, 'variable' vertex indices go first
      vertex_type =
        (vertex_index <= get_variable_count(graph) && :variable) ||
          :value

      adjust_to_matching(
        graph,
        neighbor_finder,
        vertex_index,
        vertex_type,
        direction,
        indexed_matching,
        reversed_indexed_matching
      )
    end
  end

  ## Out-neighbors
  ## If vertex is a 'variable', remove matched value from 'out' neighbors.
  ##
  ## If vertex is a 'value', make matched variable a single 'out' neighbor.
  ## Otherwise, keep neighbors as is.
  ##
  defp adjust_to_matching(
         graph,
         neighbor_finder,
         vertex_index,
         :variable,
         :out,
         variable_matching,
         _value_matching
       ) do
    case Map.get(variable_matching, vertex_index) do
      nil ->
        Empty.new()

      {value_match, _, _, _} ->
        ## Remove value from 'out' neighbors of variable vertex
        Filterer.new(neighbor_finder.(graph, vertex_index, :out), fn value -> value != value_match end)
    end
  end

  defp adjust_to_matching(
         _graph,
         _neighbor_finder,
         vertex_index,
         :value,
         :out,
         _variable_matching,
         value_matching
       ) do
    case Map.get(value_matching, vertex_index) do
      nil ->
        Empty.new()

      {variable_match, _variable, _matching_value, _variable_vertex} ->
        [variable_match]
    end
  end

  ## In-neighbors
  ## If vertex is a 'variable', make matched value a single 'in' neighbor.
  ##
  ## If vertex is a 'value', remove matched variable from 'in' neighbors.
  ##
  defp adjust_to_matching(
         _graph,
         _neighbor_finder,
         vertex_index,
         :variable,
         :in,
         variable_matching,
         _value_matching
       ) do
    case Map.get(variable_matching, vertex_index) do
      nil ->
        ## Variable outside matching
        Empty.new()

      {value_match, _variable, _matching_value, _variable_vertex} ->
        ## Matching value is the only in-neighbor
        [value_match]
    end
  end

  defp adjust_to_matching(
         graph,
         neighbor_finder,
         vertex_index,
         :value,
         :in,
         variable_matching,
         value_matching
       ) do
    neighbors = neighbor_finder.(graph, vertex_index, :in)

    Filterer.new(neighbors, fn var_neighbor ->
      ## Exclude the variable that matches the value
      ## (this would represent an 'out' edge from the value to variable, as opposed to 'in' edge)
      case Map.get(value_matching, vertex_index) do
        nil -> true
        {variable_match, _, _, _} ->
          variable_match != var_neighbor
      end
      ## All in-edges from variables have to be in matching.
      ## This makes sure that there will be no variable outside
      ## of the subgraph defined by the matching.

      && Map.has_key?(variable_matching, var_neighbor)
    end)
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

    (BitGraph.isolated_vertex?(graph, value_vertex) &&
       BitGraph.delete_vertex(graph, value_vertex)) || graph
  end

  def get_variable(variables, var_index) do
    Propagator.arg_at(variables, var_index)
  end

  def show_graph_v1(graph, context \\ nil) do
    ("context: " <>
       ((context && inspect(context)) || "") <>
       "\n" <>
       Enum.map_join(BitGraph.vertices(graph), "\n", fn vertex ->
         neighbors = BitGraph.out_neighbors(graph, vertex)

         (Enum.empty?(neighbors) && "#{inspect(vertex)} []") ||
           (
             edges = Enum.map_join(neighbors, ", ", fn neighbor -> "#{inspect(neighbor)}" end)
             "#{inspect(vertex)} -> [ #{edges} ]"
           )
       end))
    |> IO.puts()
  end

  def show_graph(graph, context \\ nil) do
    %{
      context: context,
      edges:
        BitGraph.E.edges(graph)
        |> Enum.map(fn %{from: from_index, to: to_index} ->
          {
            BitGraph.V.get_vertex(graph, from_index),
            BitGraph.V.get_vertex(graph, to_index)
          }
        end)
        |> Enum.group_by(fn {from, _to} -> from end, fn {_from, to} -> to end)
    }
  end
end
