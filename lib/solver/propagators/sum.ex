defmodule CPSolver.Propagator.Sum do
  use CPSolver.Propagator
  import CPSolver.Variable.View.Factory

  @moduledoc """
  The propagator for Sum constraint.
  Sum(y, x) constrains y to be a sum of variables in the list x.
  """
  @spec new(Variable.t(), [Variable.t()]) :: Propagator.t()
  def new(y, x) do
    new([minus(y) | x])
  end

  @impl true
  def variables([y | x]) do
    [
      set_propagate_on(y, :domain_change)
      | Enum.map(x, fn x_el -> set_propagate_on(x_el, :bound_change) end)
    ]
  end

  @impl true
  def filter([y, x]) do
    filter([y | x])
  end

  def filter(all_vars) do
    {sum_min, sum_max} =
      Enum.reduce(all_vars, {0, 0}, fn v, {s_min, s_max} = _acc ->
        {s_min + min(v), s_max + max(v)}
      end)

    if sum_min > 0 || sum_max < 0 do
      :fail
    else
      Enum.each(all_vars, fn v ->
        removeAbove(v, -(sum_min - min(v)))
        removeBelow(v, -(sum_max - max(v)))
      end)
    end
  end
end
