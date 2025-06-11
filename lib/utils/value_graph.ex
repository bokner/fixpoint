defmodule CPSolver.ValueGraph do
  alias CPSolver.Utils
  alias CPSolver.Propagator
  alias CPSolver.Variable.Interface

  def build(variables, opts \\ []) do
    ## Builds value graph and supporting structures
    ## that may be used further (for instance, fixed matching may be used by Kuhn algorithm).
    ## Value graph is bipartite.
    ## Value graph edges are {:variable, id} -> {:value, value}
    ##
    ## Fixed matching is a map {:variable, id} => {:value, value}
    ##, where variable is fixed.
    ## The set of {:variable, id} elements is a "variable" partition of value graph,
    ## that is, vertices that represent variables.
    ## Optional:
    ## :check_matching (false by default) - fails if there is no perfect matching
    ## that is, some variables fixed to the same value.
    ## Note: we do not explicitly add edges, they will be derived through
    ## BitGraph's `neighbor_finder` function based on current variables' domain values.
    ##
    check_matching? = Keyword.get(opts, :check_matching, false)
    {vertices, _var_count, left_partition, fixed, _fixed_values} = Enum.reduce(variables, {MapSet.new(), 0, MapSet.new(), Map.new(), MapSet.new()},
    fn var, {vertices_acc, var_count_acc, var_vertices_acc, fixed_matching_acc, fixed_values_acc} ->
      domain = Utils.domain_values(var)
      domain_size = MapSet.size(domain)
      var_vertex = {:variable, var_count_acc}
      vertices_acc = Enum.reduce(domain, MapSet.put(vertices_acc, var_vertex),
        fn value, acc ->
          MapSet.put(acc, {:value, value})
        end)

        var_vertices_acc = MapSet.put(var_vertices_acc, var_vertex)
        {fixed_matching_acc, fixed_values_acc} =
          if domain_size == 1 do
            fixed_value = Enum.fetch!(domain, 0)
            MapSet.member?(fixed_values_acc, fixed_value) && check_matching? && fail()
            {
              Map.put(fixed_matching_acc, var_vertex, {:value, fixed_value}),
              MapSet.put(fixed_values_acc, fixed_value)
            }
          else
            {fixed_matching_acc, fixed_values_acc}
          end
        {vertices_acc, var_count_acc + 1, var_vertices_acc, fixed_matching_acc, fixed_values_acc}
    end)
    %{graph: BitGraph.new(num_vertices: MapSet.size(vertices) |> BitGraph.add_vertices(vertices)),
      left_partition: left_partition,
      fixed: fixed
    }
  end

  defp fail() do
    throw(:fail)
  end

  def default_neighbor_finder(variables) do
    fn graph, vertex_index, direction ->
      vertex = BitGraph.V.get_vertex(graph, vertex_index)
      get_neighbors(graph, vertex, variables, direction)
    end
  end

  defp get_neighbors(_graph, {:variable, _var_index}, _variables, :in) do
    MapSet.new()
  end

  defp get_neighbors(graph, {:variable, var_index}, variables, :out) do
    Propagator.arg_at(variables, var_index)
    |> Utils.domain_values()
    |> Enum.reduce(MapSet.new(), fn value, acc -> MapSet.put(acc, BitGraph.V.get_vertex_index(graph, {:value, value})) end)
  end

  defp get_neighbors(_graph, {:value, value}, variables, :in) do
    Enum.reduce(variables, {0, MapSet.new()},
    fn var, {idx, n_acc} ->
      {idx + 1, Interface.contains?(var, value) && MapSet.put(n_acc, idx) || n_acc}
    end)
    |> elem(1)
  end

  defp get_neighbors(_graph, {:value, _value}, _variables, :out) do
    MapSet.new()
  end


end
