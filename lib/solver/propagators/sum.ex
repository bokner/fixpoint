defmodule CPSolver.Propagator.Sum do
  use CPSolver.Propagator

  @moduledoc """
  The propagator for Sum constraint.
  Sum(x, y) constrains y to be a sum of variables x.
  """
  @spec new([Variable.t()], Variable.t(), integer()) :: Propagator.t()
  def new(x, y, offset \\ 0) do
    new([x, y, offset])
  end

  @impl true
  def variables([x, y | _]) do
    [
      set_propagate_on(y, :domain_change)
      | Enum.map(x, fn x_el -> set_propagate_on(x_el, :bound_change) end)
    ]
  end

  @impl true
  def filter([x, y]) do
    filter([x, y, 0])
  end

  def filter([x, y, offset]) do
    filter([minus(y) | x], offset)
  end

  def filter(all_vars, offset \\ 0) do
    {sum_min, sum_max} = Enum.reduce(all_vars, {0, 0}, fn v, {s_min, s_max} ->
      d = Variable.domain(v)
      {s_min + Domain.min(d), s_max + Domain.max(d)}
    end)
    :stable
  end
end
