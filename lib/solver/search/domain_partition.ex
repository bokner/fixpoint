defmodule CPSolver.Search.DomainPartition do
  alias CPSolver.DefaultDomain, as: Domain
  alias CPSolver.Variable.Interface

  def partition(variable, choice) when choice in [:min, :max] do
    domain = Interface.domain(variable)
    val = apply(Domain, choice, [domain])
    split_domain_by(domain, val)
  end

  def by_min(variable) do
    partition(variable, :min)
  end

  def by_max(variable) do
    partition(variable, :max)
  end

  def random(variable) do
    domain = Interface.domain(variable)
    random_val = Domain.to_list(domain) |> Enum.random()
    split_domain_by(domain, random_val)
  end

  defp split_domain_by(domain, value) do
    case Domain.remove(domain, value) do
      :fail -> :fail
      {_domain_change, rest} -> {:ok, [value, rest]}
    end
  end
end
