defmodule CPSolver.Search.DomainPartition do
  alias CPSolver.DefaultDomain, as: Domain
  alias CPSolver.Variable.Interface

  def partition(variable, choice) when choice in [:min, :max] do
    domain = Interface.domain(variable)
    val = apply(Domain, choice, [domain])

    case Domain.remove(domain, val) do
      :fail -> :fail
      {_domain_change, rest} -> {:ok, [val, rest]}
    end
  end

  def by_min(variable) do
    partition(variable, :min)
  end

  def by_max(variable) do
    partition(variable, :max)
  end
end
