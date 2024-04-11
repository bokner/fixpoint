defmodule CPSolver.Utils.MaximumMatching do
@moduledoc """
Algorithms for finding maximum matching on graphs.
"""
alias CPSolver.Variable.Interface
alias CPSolver.DefaultDomain, as: Domain
alias CPSolver.Common

@doc """
`partial_matching` is a var_id => value map.
if no matching, `value` equals to nil
"""
def kuhn(%Graph{} = domain_graph, partial_matching) do
  kuhn(domain_graph, partial_matching, MapSet.new())
end

defp kuhn(domain_graph, partial_matching, used) do
end

@spec build_flow_network([Common.variable_or_view()]) :: Graph.t()
def build_flow_network(variables) do

  Enum.reduce(variables, {Graph.new(), 0}, fn var, {graph_acc, idx_acc} ->
    values = Interface.domain(var) |> Domain.to_list()
    {graph_acc
    |> Graph.add_edge(:s, variable_node(idx_acc), weight: 1)
    |> then(fn g -> Enum.reduce(values, g,
      fn val, g_acc ->
        g_acc
        |> Graph.add_edge(variable_node(idx_acc), value_node(idx_acc, val), weight: 1)
        |> Graph.add_edge(value_node(idx_acc, val), :t, weight: 1)
      end)
    end), idx_acc + 1}
  end)
  |> elem(0)
end

defp variable_node(idx) do
  {:variable, idx}
end

defp value_node(_var_idx, value) do
  {:value, value}
end



end
