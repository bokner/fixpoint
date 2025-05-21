defmodule CPSolver.ValueGraph do
  alias CPSolver.Utils

  def build(variables, opts \\ []) do
    ## Builds value graph and supporting structures
    ## that may be used further (for instance, by Kuhn algorithm).
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
    check_matching? = Keyword.get(opts, :check_matching, false)
    {edges, vertex_count, _var_count, left_partition, fixed, _fixed_values} = Enum.reduce(variables, {[], 0, 0, MapSet.new(), Map.new(), MapSet.new()},
    fn var, {edges_acc, vertex_count_acc, var_count_acc, var_vertices_acc, fixed_matching_acc, fixed_values_acc} ->
      domain = Utils.domain_values(var)
      domain_size = MapSet.size(domain)
      vertex_count_acc = vertex_count_acc + domain_size + 1
      var_vertex = {:variable, var_count_acc}
      edges_acc = Enum.reduce(domain, edges_acc,
        fn value, acc -> [
          {
            var_vertex,
            {:value, value}
          } | acc
          ]
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
        {edges_acc, vertex_count_acc, var_count_acc + 1, var_vertices_acc, fixed_matching_acc, fixed_values_acc}
    end)
    %{graph: BitGraph.new(num_vertices: vertex_count) |> BitGraph.add_edges(edges),
      left_partition: left_partition,
      fixed: fixed
    }
  end

  defp fail() do
    throw(:fail)
  end

end
