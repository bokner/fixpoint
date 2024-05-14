defmodule CPSolver.Propagator.AllDifferent.FWC do
  use CPSolver.Propagator

  @moduledoc """
  The forward-checking propagator for AllDifferent constraint.
  """

  @impl true
  def reset(args, nil) do
    {initial_unfixed_vars, initial_fixed_values} = initial_reduction(args)
    %{unfixed_vars: initial_unfixed_vars, fixed_values: initial_fixed_values}
  end

  def reset(args, %{fixed_values: fixed_values, unfixed_vars: unfixed_vars} = _state) do
    {unfixed_vars, delta, total_fixed} =
      Enum.reduce(
        unfixed_vars,
        {unfixed_vars, MapSet.new(), fixed_values},
        fn idx,
           {unfixed_acc, delta_acc, total_fixed_acc} =
             acc ->
          case get_value(args, idx) do
            nil ->
              acc

            value ->
              {MapSet.delete(unfixed_acc, idx), add_fixed_value(delta_acc, value),
               add_fixed_value(total_fixed_acc, value)}
          end
        end
      )

    {final_unfixed_vars, final_fixed_values} = fwc(args, unfixed_vars, delta, total_fixed)
    %{unfixed_vars: final_unfixed_vars, fixed_values: final_fixed_values}
  end

  defp initial_reduction(args) do
    Arrays.reduce(
      args,
      {0, {MapSet.new(), MapSet.new()}},
      fn var, {idx_acc, {unfixed_map_acc, fixed_set_acc}} ->
        {idx_acc + 1,
         (fixed?(var) && {unfixed_map_acc, add_fixed_value(fixed_set_acc, min(var))}) ||
           {MapSet.put(unfixed_map_acc, idx_acc), fixed_set_acc}}
      end
    )
    |> elem(1)
    |> then(fn {unfixed_vars, fixed_values} ->
      fwc(args, unfixed_vars, fixed_values, fixed_values)
    end)
  end

  @impl true
  def arguments(args) do
    Arrays.new(args)
  end

  @impl true
  def variables(args) do
    Enum.map(args, fn x_el -> set_propagate_on(x_el, :fixed) end)
  end

  @impl true
  def filter(args) do
    filter(args, initial_reduction(args))
  end

  @impl true
  def filter(all_vars, state, changes) do
    {unfixed_vars, fixed_values} =
      if state do
        {state.unfixed_vars, state.fixed_values}
      else
        initial_reduction(all_vars)
      end

    {updated_unfixed_vars, updated_fixed_values} =
      filter_impl(all_vars, unfixed_vars, fixed_values, changes)

    {:state, %{unfixed_vars: updated_unfixed_vars, fixed_values: updated_fixed_values}}
  end

  defp filter_impl(all_vars, unfixed_vars, fixed_values, changes) when is_map(changes) do
    {new_unfixed_vars, new_fixed_values, all_fixed_values} =
      prepare_changes(all_vars, unfixed_vars, fixed_values, changes)

    fwc(all_vars, new_unfixed_vars, new_fixed_values, all_fixed_values)
  end

  defp prepare_changes(all_vars, unfixed_vars, previously_fixed_values, changes) do
    Enum.reduce(
      changes,
      {unfixed_vars, MapSet.new(), previously_fixed_values},
      fn {idx, :fixed}, {unfixed_vars_acc, fixed_values_acc, all_fixed_values_acc} = acc ->
        if MapSet.member?(unfixed_vars_acc, idx) do
          updated_vars = MapSet.delete(unfixed_vars_acc, idx)
          fixed_value = get_value(all_vars, idx)

          {updated_vars, add_fixed_value(fixed_values_acc, fixed_value),
           add_fixed_value(all_fixed_values_acc, fixed_value)}
        else
          acc
        end
      end
    )
  end

  defp fwc(all_vars, unfixed_vars, current_delta, accumulated_fixed_values) do
    {updated_unfixed_vars, _fixed_values, new_delta} =
      Enum.reduce(
        unfixed_vars,
        {unfixed_vars, current_delta, MapSet.new()},
        fn idx, {unfixed_vars_acc, fixed_values_acc, new_delta_acc} ->
          case remove_all(get_variable(all_vars, idx), fixed_values_acc) do
            ## No new fixed variables
            false ->
              {unfixed_vars_acc, fixed_values_acc, new_delta_acc}

            new_fixed_value ->
              {MapSet.delete(unfixed_vars_acc, idx),
               MapSet.put(fixed_values_acc, new_fixed_value),
               MapSet.put(new_delta_acc, new_fixed_value)}
          end
        end
      )

    updated_accumulated_fixed_values = MapSet.union(accumulated_fixed_values, new_delta)

    if MapSet.size(new_delta) == 0 do
      {updated_unfixed_vars, updated_accumulated_fixed_values}
    else
      fwc(all_vars, updated_unfixed_vars, new_delta, updated_accumulated_fixed_values)
    end

    ##
  end

  ## Remove values from the domain of variable
  ## Note: if the variable gets fixed at some point,
  ## we can stop by checking if the fixed value is already present in the set of values.
  ## If that's the case, we'll fail (duplicate fixed value!),
  ## otherwise we exit the loop, as there is no point to continue.
  defp remove_all(nil, _values) do
    false
  end

  defp remove_all(variable, values) do
    Enum.reduce_while(
      values,
      false,
      fn value, _acc ->
        case remove(variable, value) do
          :fixed ->
            fixed_value = min(variable)
            (MapSet.member?(values, fixed_value) && throw(:fail)) || {:halt, fixed_value}

          _not_fixed ->
            {:cont, false}
        end
      end
    )
  end

  defp add_fixed_value(fixed_values, nil) do
    fixed_values
  end

  defp add_fixed_value(fixed_values, value) do
    (MapSet.member?(fixed_values, value) && throw(:fail)) ||
      MapSet.put(fixed_values, value)
  end

  defp get_value(_variables, nil) do
    nil
  end

  defp get_value(variables, idx) do
    case get_variable(variables, idx) do
      nil ->
        nil

      var ->
        (fixed?(var) && min(var)) || nil
    end
  end

  defp get_variable(variables, idx) do
    (idx && Propagator.arg_at(variables, idx)) || nil
  end
end
