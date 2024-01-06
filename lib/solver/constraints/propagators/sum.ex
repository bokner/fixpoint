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

  defp initial_state(args) do
    {sum_fixed, unfixed_vars} =
      Enum.reduce(args, {0, []}, fn var, {sum_acc, unfixed_acc} ->
        (fixed?(var) && {sum_acc + min(var), unfixed_acc}) ||
          {sum_acc, [var | unfixed_acc]}
      end)

    %{sum_fixed: sum_fixed, unfixed_vars: unfixed_vars}
  end

  @impl true
  def variables([y | x]) do
    [
      set_propagate_on(y, :domain_change)
      | Enum.map(x, fn x_el -> set_propagate_on(x_el, :bound_change) end)
    ]
  end

  @impl true
  def filter(args) do
    filter(args, initial_state(args))
  end

  def filter(args, nil) do
    filter(args, initial_state(args))
  end

  @impl true
  def filter(_all_vars, %{sum_fixed: sum_fixed, unfixed_vars: unfixed_vars} = _state) do
    {updated_unfixed_vars, new_sum} = update_unfixed(unfixed_vars)
    updated_sum = sum_fixed + new_sum
    {sum_min, sum_max} = sum_min_max(updated_sum, updated_unfixed_vars)

    case filter_impl(updated_unfixed_vars, sum_min, sum_max) do
      :fail -> :fail
      :ok -> {:state, %{sum_fixed: updated_sum, unfixed_vars: updated_unfixed_vars}}
    end
  end

  defp update_unfixed(unfixed_vars) do
    Enum.reduce(unfixed_vars, {[], 0}, fn var, {unfixed_acc, sum_acc} ->
      (fixed?(var) && {unfixed_acc, sum_acc + min(var)}) ||
        {[var | unfixed_acc], sum_acc}
    end)
  end

  defp filter_impl(variables, sum_min, sum_max) do
    (unsatisfiable(sum_min, sum_max) && :fail) ||
      case update_partial_sums(variables, sum_min, sum_max) do
        {new_sum_min, new_sum_max} ->
          ## Enforce idempotence: we'll run filtering until there's no changes
          ((new_sum_min != sum_min ||
              new_sum_max != sum_max) && filter_impl(variables, new_sum_min, new_sum_max)) ||
            :ok

        :fail ->
          :fail
      end
  end

  defp update_partial_sums(variables, sum_min, sum_max) do
    Enum.reduce_while(variables, {sum_min, sum_max}, fn v, {s_min, s_max} ->
      min_v = min(v)
      max_v = max(v)

      new_max = maybe_update_max(v, max_v, removeAbove(v, -(s_min - min_v)))
      new_min = maybe_update_min(v, min_v, removeBelow(v, -(s_max - max_v)))
      new_sum_min = s_min + new_min - min_v
      new_sum_max = s_max + max_v - new_max

      (unsatisfiable(new_sum_min, new_sum_max) && {:halt, :fail}) ||
        {:cont, {new_sum_min, new_sum_max}}
    end)
  end

  ## Some optimization: if removeAbove/removeBelow don't change the domain,
  ## save the additional max/min call.
  defp maybe_update_max(_var, current_max, :no_change) do
    current_max
  end

  defp maybe_update_max(var, _current_max, _domain_change) do
    max(var)
  end

  defp maybe_update_min(_var, current_min, :no_change) do
    current_min
  end

  defp maybe_update_min(var, _current_min, _domain_change) do
    min(var)
  end

  defp sum_min_max(sum_fixed, unfixed_variables) do
    Enum.reduce(unfixed_variables, {sum_fixed, sum_fixed}, fn v, {s_min, s_max} = _acc ->
      {s_min + min(v), s_max + max(v)}
    end)
  end

  defp unsatisfiable(sum_min, sum_max) do
    sum_min > 0 || sum_max < 0
  end
end
