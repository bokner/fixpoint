defmodule CPSolver.Search.DomainPartition do
  alias CPSolver.DefaultDomain, as: Domain

  def by_min(domain) do
    min_val = Domain.min(domain)
    {_domain_change, rest} = Domain.remove(domain, min_val)
    [min_val, rest]
  end
end
