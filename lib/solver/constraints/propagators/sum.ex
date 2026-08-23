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
  def arguments(args) do
    Vector.new(args)
  end

  defp initial_state(args) do
    {_idx, sum_fixed, unfixed_vars} =
      args
      |> Enum.reduce({0, 0, MapSet.new()}, fn var, {idx_acc, sum_acc, unfixed_acc} ->
        next_idx = idx_acc + 1

        (fixed?(var) && {next_idx, sum_acc + min(var), unfixed_acc}) ||
          {next_idx, sum_acc, MapSet.put(unfixed_acc, idx_acc)}
      end)

    %{sum_fixed: sum_fixed, unfixed_ids: unfixed_vars}
  end

  @impl true
  def variables([y | x]) do
    [
      set_propagate_on(y, :domain_change)
      | Enum.map(x, fn x_el -> set_propagate_on(x_el, :bound_change) end)
    ]
  end

  @impl true
  def filter(all_vars, nil, changes) do
    filter(all_vars, initial_state(all_vars), changes)
  end

  def filter(all_vars, %{sum_fixed: sum_fixed, unfixed_ids: unfixed_ids} = _state, changes) do
    {updated_unfixed_ids, updated_sum_fixed, sum_min, sum_max} =
      apply_changes(all_vars, unfixed_ids, sum_fixed, changes)

    filter_impl(all_vars, updated_unfixed_ids, sum_min, sum_max)
    {:state, %{sum_fixed: updated_sum_fixed, unfixed_ids: updated_unfixed_ids}}
  end

  defp apply_changes(all_vars, unfixed_ids, sum_fixed, changes) do
    Enum.reduce(unfixed_ids, {unfixed_ids, sum_fixed, sum_fixed, sum_fixed}, fn pos,
                                                                                    {unfixed_ids_acc,
                                                                                     sum_acc,
                                                                                     sum_min_acc,                                                                                     sum_max_acc} ->
      var = Propagator.arg_at(all_vars, pos)

      if Map.get(changes, pos) == :fixed do
        min_var = min(var)
        sum_min_acc = sum_min_acc + min_var
        sum_max_acc = sum_max_acc + min_var
        {MapSet.delete(unfixed_ids_acc, pos), sum_acc + min(var), sum_min_acc, sum_max_acc}
      else
        sum_min_acc = sum_min_acc + min(var)
        sum_max_acc = sum_max_acc + max(var)
        {unfixed_ids_acc, sum_acc, sum_min_acc, sum_max_acc}
      end
    end)
  end

  defp filter_impl(variables, unfixed_ids, sum_min, sum_max) do
    {new_sum_min, new_sum_max} = update_partial_sums(variables, unfixed_ids, sum_min, sum_max)
    test_unsatisfiable(new_sum_min, new_sum_max)
    ## Enforce idempotence: we'll run filtering until there's no changes
    ((new_sum_min != sum_min ||
        new_sum_max != sum_max) && filter_impl(variables, unfixed_ids, new_sum_min, new_sum_max)) ||
      :ok
  end

  defp update_partial_sums(variables, unfixed_ids, sum_min, sum_max) do
    Enum.reduce(unfixed_ids, {sum_min, sum_max}, fn pos, {s_min, s_max} ->
      v = Propagator.arg_at(variables, pos)
      min_v = min(v)
      max_v = max(v)

      removeAbove(v, -(s_min - min_v))
      removeBelow(v, -(s_max - max_v))
      new_max = max(v)
      new_min = min(v)
      new_sum_min = s_min + new_min - min_v
      new_sum_max = s_max + max_v - new_max

      test_unsatisfiable(new_sum_min, new_sum_max)
      {new_sum_min, new_sum_max}
    end)
  end

  defp test_unsatisfiable(sum_min, sum_max) do
    (sum_min > 0 || sum_max < 0) && fail()
  end

  defp fail() do
    throw(:fail)
  end
end
