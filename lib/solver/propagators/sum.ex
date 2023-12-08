defmodule CPSolver.Propagator.Sum do
  use CPSolver.Propagator
  import CPSolver.Variable.View.Factory

  @moduledoc """
  The propagator for Sum constraint.
  Sum(y, x) constrains y to be a sum of variables in the list x.
  """
  @spec new(Common.variable_or_view(), [Common.variable_or_view()]) :: Propagator.t()
  def new(y, x) do
    new([minus(y) | x])
  end

  @impl true
  def variables([y | x]) do
    [
      set_propagate_on(y, :domain_change)
      | Enum.map(hd(x), fn x_el -> set_propagate_on(x_el, :bound_change) end)
    ]
  end

  @impl true
  def filter([y, x]) do
    filter([y | x])
  end

  def filter(all_vars) do
    {sum_min, sum_max} = sum_min_max(all_vars)
    filter_impl(all_vars, sum_min, sum_max)
  end

  defp filter_impl(variables, sum_min, sum_max) do
    case Enum.reduce_while(variables, {0, 0}, fn v, {s_min, s_max} ->
           if sum_min > 0 || sum_max < 0 do
             {:halt, :fail}
           else
             ((removeAbove(v, -(sum_min - min(v))) == :fail ||
                 removeBelow(v, -(sum_max - max(v))) == :fail) && {:halt, :fail}) ||
               {:cont, {s_min + min(v), s_max + max(v)}}
           end
         end) do
      :fail ->
        :fail

      ## Enforce idempotence: we'll run filtering until there's no changes
      {new_sum_min, new_sum_max} ->
        ((new_sum_min != sum_min ||
            new_sum_max != sum_max) && filter_impl(variables, new_sum_min, new_sum_max)) ||
          :ok
    end
  end

  defp sum_min_max(variables) do
    Enum.reduce(variables, {0, 0}, fn v, {s_min, s_max} = _acc ->
      {s_min + min(v), s_max + max(v)}
    end)
  end
end
