defmodule CPSolver.DefaultDomain do
  alias CPSolver.BitVectorDomain.V2, as: Domain

  defdelegate new(values), to: Domain

  def map(domain, mapper) do
    (Domain.failed?(domain) && fail()) || Domain.map(domain, mapper)
  end

  def remove(domain, val) do
    (Domain.failed?(domain) && fail()) || Domain.remove(domain, val)
  end

  def removeAbove(domain, val) do
    (Domain.failed?(domain) && fail()) || Domain.removeAbove(domain, val)
  end

  def removeBelow(domain, val) do
    (Domain.failed?(domain) && fail()) || Domain.removeBelow(domain, val)
  end

  def to_list(arg) when is_integer(arg) do
    [arg]
  end

  def to_list(arg) when is_list(arg) do
    arg
  end

  def to_list(domain) do
    (Domain.failed?(domain) && fail()) || Domain.to_list(domain)
  end

  def copy(domain) do
    domain
    |> Domain.to_list()
    |> Domain.new()
  end

  def size(domain) do
    (Domain.failed?(domain) && fail()) || Domain.size(domain)
  end

  def fixed?(domain) do
    (Domain.failed?(domain) && fail()) || Domain.fixed?(domain)
  end

  def contains?(domain, value) do
    (Domain.failed?(domain) && fail()) || Domain.contains?(domain, value)
  end

  def min(domain) do
    (Domain.failed?(domain) && fail()) || Domain.min(domain)
  end

  def max(domain) do
    (Domain.failed?(domain) && fail()) || Domain.max(domain)
  end

  def fix(domain, value) do
    (Domain.failed?(domain) && fail()) || Domain.fix(domain, value)
  end

  defp fail() do
    throw(:fail)
  end
end
