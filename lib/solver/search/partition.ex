defmodule CPSolver.Search.DomainPartition do
  alias CPSolver.DefaultDomain, as: Domain

  def partition(domain, choice) when choice in [:min, :max] do
    val = apply(Domain, choice, [domain])

    case Domain.remove(domain, val) do
      :fail -> :fail
      {_domain_change, rest} -> {:ok, [val, rest]}
    end
  end

  def by_min(domain) do
    partition(domain, :min)
  end
  def by_max(domain) do
    partition(domain, :max)
  end
end
