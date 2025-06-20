defmodule CPSolver.ValueGraph do
  alias CPSolver.Utils
  alias CPSolver.Variable.Interface
  alias CPSolver.Propagator

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

    {value_vertices, var_count, fixed, _fixed_values} =
      Enum.reduce(variables, {MapSet.new(), 0, Map.new(), MapSet.new()}, fn var,
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
      end)

    %{
      graph:
        BitGraph.new(num_vertices: MapSet.size(value_vertices) + var_count)
        |> then(fn g ->
          Enum.reduce(0..(var_count - 1), g, fn idx, g_acc ->
            BitGraph.add_vertex(g_acc, {:variable, idx})
          end)
        end)
        |> BitGraph.add_vertices(value_vertices),
      left_partition: MapSet.new(0..(var_count - 1), fn idx -> {:variable, idx} end),
      fixed: fixed
    }
  end

  defp fail(reason \\ :fail) do
    throw(reason)
  end

  def default_neighbor_finder(variables) do
    fn graph, vertex_index, direction ->
      vertex = BitGraph.V.get_vertex(graph, vertex_index)
      get_neighbors(graph, vertex, variables, direction)
    end
  end

  defp get_neighbors(_graph, {:variable, _var_index}, _variables, :in) do
    MapSet.new([])
  end

  defp get_neighbors(_graph, {:value, _value}, _variables, :out) do
    MapSet.new([])
  end

  defp get_neighbors(graph, {:variable, var_index}, variables, :out) do
    Propagator.arg_at(variables, var_index)
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

  ## Matching edges will be reversed
  def matching_neighbor_finder(graph, variables, matching) do
    default_neighbor_finder = default_neighbor_finder(variables)

    {indexed_matching, reversed_indexed_matching} =
      Enum.reduce(matching, {Map.new(), Map.new()}, fn {{:variable, var_index} = var_vertex,
                                                        {:value, value} = value_vertex},
                                                       {matching_acc, reverse_matching_acc} ->
        propagator_variable = Propagator.arg_at(variables, var_index)

        Interface.contains?(propagator_variable, value) ||
          fail({:invalid_matching, var_vertex, value_vertex})

        var_vertex_index = BitGraph.V.get_vertex_index(graph, var_vertex)
        value_vertex_index = BitGraph.V.get_vertex_index(graph, value_vertex)

        {
          Map.put(
            matching_acc,
            var_vertex_index,
            {value_vertex_index, propagator_variable, value, var_vertex}
          ),
          # value_vertex_index),
          Map.put(
            reverse_matching_acc,
            value_vertex_index,
            {var_vertex_index, propagator_variable, value, var_vertex}
          )
          # var_vertex_index)
        }
      end)

    fn graph, vertex_index, direction ->
      neighbors = default_neighbor_finder.(graph, vertex_index, direction)

      adjust_neighbors(
        neighbors,
        vertex_index,
        indexed_matching,
        reversed_indexed_matching,
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
         indexed_matching,
         reversed_indexed_matching,
         :out
       ) do
    case Map.get(indexed_matching, vertex_index) do
      nil ->
        case Map.get(reversed_indexed_matching, vertex_index) do
          nil ->
            neighbors

          {variable_match, variable, matching_value, variable_vertex} ->
            (Interface.contains?(variable, matching_value) &&
               MapSet.new([variable_match])) ||
              fail({:invalid_matching, variable_vertex, {:value, matching_value}})
        end

      {value_match, _, _, _} ->
        ## Remove value from 'out' neighbors of variable vertex
        MapSet.delete(neighbors, value_match)
    end
  end

  ## In-neighbors
  ## If vertex is a 'variable', make matched value a single 'in' neighbor.
  ##
  ## If vertex is a 'value', remove matched variable from 'in' neighbors.
  ##
  defp adjust_neighbors(neighbors, vertex_index, indexed_matching, reversed_indexed_matching, :in) do
    case Map.get(reversed_indexed_matching, vertex_index) do
      nil ->
        case Map.get(indexed_matching, vertex_index) do
          ## All variables have to have a matched value (unlikely failure!)
          nil ->
            fail(:unmatched_variable)

          {value_match, variable, matching_value, variable_vertex} ->
            (Interface.contains?(variable, matching_value) &&
               MapSet.new([value_match])) ||
              fail({:invalid_matching, variable_vertex, {:value, matching_value}})
        end

      {variable_match, _, _, _} ->
        MapSet.delete(neighbors, variable_match)
    end
  end
end
