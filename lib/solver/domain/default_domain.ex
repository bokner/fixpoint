defmodule CPSolver.DefaultDomain do
  alias CPSolver.BitVectorDomain.V2, as: Domain

  defdelegate new(values), to: Domain

  def map(fixed, mapper) when is_integer(fixed) do
    [mapper.(fixed)]
  end

  def map(domain, mapper) do
    Domain.map(domain, mapper)
  end

  def remove(fixed, val) when is_integer(fixed) do
    (fixed == val && fail()) || :no_change
  end

  def remove(domain, val) do
    Domain.remove(domain, val)
  end

  def removeAbove(fixed, val) when is_integer(fixed) do
    (val < fixed && fail()) || :no_change
  end

  def removeAbove(domain, val) do
    Domain.removeAbove(domain, val)
  end

  def removeBelow(fixed, val) when is_integer(fixed) do
    (val > fixed && fail()) || :no_change
  end

  def removeBelow(domain, val) do
    Domain.removeBelow(domain, val)
  end

  def to_list(arg) when is_integer(arg) do
    [arg]
  end

  def to_list(arg) when is_list(arg) do
    arg
  end

  def to_list(domain) do
    Domain.to_list(domain)
  end

  def copy(fixed) when is_integer(fixed) do
    fixed
  end

  def copy(domain) do
    Domain.copy(domain)
  end

  def size(fixed) when is_integer(fixed) do
    1
  end

  def size(domain) do
    Domain.size(domain)
  end

  def fixed?(fixed) when is_integer(fixed) do
    true
  end

  def fixed?(domain) do
    Domain.fixed?(domain)
  end

  def contains?(fixed, value) when is_integer(fixed) do
    fixed == value
  end

  def contains?(domain, value) do
    Domain.contains?(domain, value)
  end

  def min(fixed) when is_integer(fixed) do
    fixed
  end

  def min(domain) do
    Domain.min(domain)
  end

  def max(fixed) when is_integer(fixed) do
    fixed
  end

  def max(domain) do
    Domain.max(domain)
  end

  def fix(fixed, value) when is_integer(fixed) do
    (fixed == value && :no_change) || fail()
  end

  def fix(domain, value) do
    Domain.fix(domain, value)
  end

  defp fail() do
    throw(:fail)
  end
end
