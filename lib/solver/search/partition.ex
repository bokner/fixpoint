defmodule CPSolver.Search.DomainPartition do
  alias CPSolver.DefaultDomain, as: Domain

  def by_min(domain) do
    min_val = Domain.min(domain)

    case Domain.remove(domain, min_val) do
      :fail -> :fail
      {_domain_change, rest} -> {:ok, [min_val, rest]}
    end
  end
end
