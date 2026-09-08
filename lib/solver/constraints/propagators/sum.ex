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
  def variables(vars) do
    Enum.map(vars, fn var -> set_propagate_on(var, :bound_change) end)
  end

  @impl true
  def filter(all_vars, nil, changes) do
    filter(all_vars, initial_state(all_vars), changes)
  end

  def filter(all_vars, %{sum_fixed: sum_fixed, unfixed_ids: unfixed_ids} = _state, changes) do
    {sum_fixed, sum_min, sum_max, updated_unfixed_ids} =
      apply_changes(all_vars, unfixed_ids, sum_fixed, changes)

    state = filter_impl(all_vars, updated_unfixed_ids, sum_min, sum_max, sum_fixed)
    {:state, state}
  end

  defp apply_changes(all_vars, unfixed_ids, sum_fixed, _changes) do
    Enum.reduce(unfixed_ids, {sum_fixed, sum_fixed, sum_fixed, MapSet.new()}, fn pos,
                                                                                 {
                                                                                   sum_acc,
                                                                                   sum_min_acc,
                                                                                   sum_max_acc,
                                                                                   unfixed_ids_acc
                                                                                 } ->
      var = Propagator.arg_at(all_vars, pos)

      if fixed?(var) do
        min_var = min(var)
        sum_min_acc = sum_min_acc + min_var
        sum_max_acc = sum_max_acc + min_var
        {sum_acc + min(var), sum_min_acc, sum_max_acc, unfixed_ids_acc}
      else
        sum_min_acc = sum_min_acc + min(var)
        sum_max_acc = sum_max_acc + max(var)
        {sum_acc, sum_min_acc, sum_max_acc, MapSet.put(unfixed_ids_acc, pos)}
      end
    end)
  end

  defp filter_impl(variables, unfixed_ids, sum_min, sum_max, sum_fixed) do
    {new_sum_min, new_sum_max, new_sum_fixed, new_unfixed_ids, domain_changes?} =
      update_partial_sums(variables, unfixed_ids, sum_min, sum_max, sum_fixed)

    test_unsatisfiable(new_sum_min, new_sum_max, new_sum_fixed, new_unfixed_ids)
    ## Enforce idempotence: we'll run filtering until there's no changes
    if domain_changes? do
      filter_impl(variables, new_unfixed_ids, new_sum_min, new_sum_max, new_sum_fixed)
    else
      %{sum_fixed: new_sum_fixed, unfixed_ids: new_unfixed_ids}
    end
  end

  defp update_partial_sums(variables, unfixed_ids, sum_min, sum_max, sum_fixed) do
    Enum.reduce(unfixed_ids, {sum_min, sum_max, sum_fixed, MapSet.new(), false}, fn pos,
                                                                                    {s_min, s_max,
                                                                                     s_fixed,
                                                                                     unfixed_ids_acc,
                                                                                     changed_acc?} ->
      v = Propagator.arg_at(variables, pos)
      min_v = min(v)
      max_v = max(v)

      above_change = removeAbove(v, -(s_min - min_v))
      below_change = removeBelow(v, -(s_max - max_v))
      new_max = max(v)
      new_min = min(v)
      new_sum_min = s_min + new_min - min_v
      new_sum_max = s_max + max_v - new_max

      {new_partial_sum, new_unfixed_ids_acc} =
        if fixed?(v) do
          {s_fixed + new_min, unfixed_ids_acc}
        else
          {s_fixed, MapSet.put(unfixed_ids_acc, pos)}
        end

      {new_sum_min, new_sum_max, new_partial_sum, new_unfixed_ids_acc,
       changed_acc? || above_change != :no_change || below_change != :no_change}
    end)
  end

  defp test_unsatisfiable(sum_min, sum_max, sum_fixed, unfixed_ids) do
    if sum_min > 0 || sum_max < 0 || (Enum.empty?(unfixed_ids) && sum_fixed != 0) do
      fail()
    end
  end

  defp fail() do
    throw(:fail)
  end
end
