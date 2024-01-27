defmodule CPSolver.DefaultDomain do
  alias CPSolver.BitVectorDomain, as: Domain

  defdelegate new(values), to: Domain
  defdelegate map(domain, mapper), to: Domain
  defdelegate size(values), to: Domain
  defdelegate min(values), to: Domain
  defdelegate max(values), to: Domain
  defdelegate fixed?(values), to: Domain
  defdelegate contains?(values, val), to: Domain
  defdelegate remove(values, val), to: Domain
  defdelegate removeAbove(values, val), to: Domain
  defdelegate removeBelow(values, val), to: Domain
  defdelegate fix(values, val), to: Domain

  def to_list(arg) when is_list(arg) do
    arg
  end

  def to_list(arg) do
    Domain.to_list(arg)
  end

  def copy(domain) do
    domain
    |> Domain.to_list()
    |> Domain.new()
  end
end
