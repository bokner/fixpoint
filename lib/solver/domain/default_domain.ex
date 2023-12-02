defmodule CPSolver.DefaultDomain do
  alias CPSolver.Common

  @spec new(Enum.t()) :: :gb_sets.set(number())
  def new([]) do
    throw(:empty_domain)
  end

  def new(domain) when is_integer(domain) do
    :gb_sets.from_list([domain])
  end

  def new(domain) do
    (:gb_sets.is_set(domain) && domain) ||
      Enum.reduce(domain, :gb_sets.new(), fn v, acc -> :gb_sets.add_element(v, acc) end)
  end

  def map(domain, mapper_fun) when is_function(mapper_fun) do
    :gb_sets.fold(
      fn v, acc -> :gb_sets.add_element(mapper_fun.(v), acc) end,
      :gb_sets.new(),
      domain
    )
  end

  def to_list(domain) do
    :gb_sets.to_list(domain)
  end

  @spec size(:gb_sets.set(number())) :: non_neg_integer
  def size(domain) do
    :gb_sets.size(domain)
  end

  @spec fixed?(:gb_sets.set(number())) :: boolean
  def fixed?(domain) do
    size(domain) == 1
  end

  @spec min(:gb_sets.set(number())) :: number()
  def min(domain) do
    :gb_sets.smallest(domain)
  end

  @spec max(domain :: :gb_sets.set(number())) :: number()
  def max(domain) do
    :gb_sets.largest(domain)
  end

  @spec contains?(:gb_sets.set(number()), number()) :: boolean
  def contains?(domain, value) do
    :gb_sets.is_member(value, domain)
  end

  @spec remove(:gb_sets.set(number()), number()) ::
          :fail
          | :no_change
          | {Common.domain_change(), :gb_sets.set(number())}
  def remove(domain, value) do
    :gb_sets.delete_any(value, domain)
    |> post_remove(domain, :domain_change)
  end

  @spec removeAbove(:gb_sets.set(number()), number()) ::
          :fail
          | :no_change
          | {Common.domain_change(), :gb_sets.set(number())}

  def removeAbove(domain, value) do
    :gb_sets.filter(fn v -> v <= value end, domain)
    |> post_remove(domain, :max_change)
  end

  @spec removeBelow(:gb_sets.set(number()), number()) ::
          :fail | :no_change | {Common.domain_change(), :gb_sets.set(number())}
  def removeBelow(domain, value) do
    :gb_sets.filter(fn v -> v >= value end, domain)
    |> post_remove(domain, :min_change)
  end

  @spec fix(:gb_sets.set(any), number()) :: :fail | {:fixed, :gb_sets.set(number())}
  def fix(domain, value) do
    if contains?(domain, value) do
      {:fixed, :gb_sets.from_list([value])}
    else
      :fail
    end
  end

  defp post_remove(new_domain, domain, change_kind) do
    case size(new_domain) do
      0 ->
        :fail

      new_size ->
        case size(domain) do
          old_size when old_size == new_size ->
            :no_change

          old_size when old_size > new_size ->
            {(new_size == 1 && :fixed) || maybe_bound_change(change_kind, new_domain, domain),
             new_domain}
        end
    end
  end

  defp maybe_bound_change(change_kind, new_domain, domain) do
    (min(new_domain) > min(domain) && :min_change) ||
      (max(new_domain) > max(domain) && :max_change) ||
      change_kind
  end
end
