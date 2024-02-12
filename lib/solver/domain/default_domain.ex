defmodule CPSolver.DefaultDomain do
  alias CPSolver.BitVectorDomain, as: Domain

  defdelegate new(values), to: Domain
  defdelegate map(domain, mapper), to: Domain
  defdelegate remove(values, val), to: Domain
  defdelegate removeAbove(values, val), to: Domain
  defdelegate removeBelow(values, val), to: Domain

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

  def size(domain) when is_integer(domain) do
    1
  end

  def size(domain) do
    Domain.size(domain)
  end

  def fixed?(domain) when is_integer(domain) do
    true
  end

  def fixed?(domain) do
    Domain.fixed?(domain)
  end

  def contains?(domain, value) when is_integer(domain) do
    domain == value
  end

  def contains?(domain, value) do
    Domain.contains?(domain, value)
  end

  def min(domain) when is_integer(domain) do
    domain
  end

  def min(domain) do
    Domain.min(domain)
  end

  def max(domain) when is_integer(domain) do
    domain
  end

  def max(domain) do
    Domain.max(domain)
  end

  def fix(domain, value) when is_integer(domain) do
    (domain != value && :fail) || :no_change
  end

  def fix(domain, value) do
    Domain.fix(domain, value)
  end
end
