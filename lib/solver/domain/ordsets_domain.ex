defmodule CPSolver.OrdSetsDomain do
  alias CPSolver.Common

  @spec new(Enum.t()) :: :ordsets.set(number())
  def new([]) do
    throw(:empty_domain)
  end

  def new(domain) when is_integer(domain) do
    :ordsets.from_list([domain])
  end

  def new(domain) do
    (:ordsets.is_set(domain) && domain) ||
      Enum.reduce(domain, :ordsets.new(), fn v, acc -> :ordsets.add_element(v, acc) end)
  end

  def map(domain, mapper_fun) when is_function(mapper_fun) do
    :ordsets.fold(
      fn v, acc -> :ordsets.add_element(mapper_fun.(v), acc) end,
      :ordsets.new(),
      domain
    )
  end

  def to_list(domain) do
    :ordsets.to_list(domain)
  end

  @spec size(:ordsets.set(number())) :: non_neg_integer
  def size(domain) do
    :ordsets.size(domain)
  end

  @spec fixed?(:ordsets.set(number())) :: boolean
  def fixed?(domain) do
    size(domain) == 1
  end

  @spec min(:ordsets.set(number())) :: number()
  def min(domain) do
    hd(domain)
  end

  @spec max(domain :: :ordsets.set(number())) :: number()
  def max(domain) do
    List.last(domain)
  end

  @spec contains?(:ordsets.set(number()), number()) :: boolean
  def contains?(domain, value) do
    :ordsets.is_element(value, domain)
  end

  @spec remove(:ordsets.set(number()), number()) ::
          :fail
          | :no_change
          | {Common.domain_change(), :ordsets.set(number())}
  def remove(domain, value) do
    :ordsets.del_element(value, domain)
    |> post_remove(domain, :domain_change)
  end

  @spec removeAbove(:ordsets.set(number()), number()) ::
          :fail
          | :no_change
          | {Common.domain_change(), :ordsets.set(number())}

  def removeAbove(domain, value) do
    Enum.take_while(domain, fn v -> v <= value end)
    |> post_remove(domain, :max_change)
  end

  @spec removeBelow(:ordsets.set(number()), number()) ::
          :fail | :no_change | {Common.domain_change(), :ordsets.set(number())}
  def removeBelow(domain, value) do
    Enum.drop_while(domain, fn v -> v < value end)
    |> post_remove(domain, :min_change)
  end

  @spec fix(:ordsets.set(any), number()) :: :fail | {:fixed, :ordsets.set(number())}
  def fix(domain, value) do
    if contains?(domain, value) do
      {:fixed, :ordsets.from_list([value])}
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
      (max(new_domain) < max(domain) && :max_change) ||
      change_kind
  end
end
