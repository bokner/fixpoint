defmodule CPSolver.Propagator.AllDifferent.FWC do
  use CPSolver.Propagator

  @moduledoc """
  The forward-checking propagator for AllDifferent constraint.
  """

  @impl true
  def reset(_args, state) do
    nil
  end

  def reset(args, %{unfixed_vars: unfixed, fixed_values: fixed} = _state) do
    ## Refresh the state:
    ## find and apply new fixed values
    Enum.reduce(unfixed, {unfixed, MapSet.new(), fixed}, fn {_ref, idx}, {unfixed_acc, fixed_acc, total_fixed_acc} ->
      var = get_variable(args, idx)
      if fixed?(var) do
        new_value = min(var)
        {Map.delete(unfixed_acc, idx),
          add_fixed_value(fixed_acc, new_value),
          add_fixed_value(total_fixed_acc, new_value),
        }
      else
        {unfixed_acc, fixed_acc, total_fixed_acc}
      end
    end)
    |> then(fn {new_unfixed, new_fixed, total_fixed} ->
      #{final_unfixed, final_fixed} = fwc(args, new_unfixed, new_fixed, total_fixed)
      %{unfixed_vars: new_unfixed, fixed_values: MapSet.union(fixed, new_fixed)}
    end)
  end

  defp initial_reduction(args) do
    Enum.reduce(
      args,
      {0, {Map.new(), MapSet.new()}},
      fn var, {idx_acc, {unfixed_map_acc, fixed_set_acc}} ->
        {idx_acc + 1,
         (fixed?(var) && {unfixed_map_acc, add_fixed_value(fixed_set_acc, min(var))}) ||
           {Map.put(unfixed_map_acc, id(var), idx_acc), fixed_set_acc}}
      end
    )
    |> elem(1)
    |> then(fn {unfixed_vars, fixed_values} ->
      fwc(args, unfixed_vars, fixed_values, fixed_values)
    end)
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
      fn {var_id, :fixed}, {unfixed_vars_acc, fixed_values_acc, all_fixed_values_acc} ->
        {idx, updated_vars} = Map.pop(unfixed_vars_acc, var_id)
        fixed_value = get_value(all_vars, idx)

        {updated_vars, add_fixed_value(fixed_values_acc, fixed_value),
         add_fixed_value(all_fixed_values_acc, fixed_value)}
      end
    )
  end

  defp fwc(all_vars, unfixed_vars, current_delta, accumulated_fixed_values) do
    {updated_unfixed_vars, _fixed_values, new_delta} =
      Enum.reduce(
        unfixed_vars,
        {unfixed_vars, current_delta, MapSet.new()},
        fn {ref, idx}, {unfixed_vars_acc, fixed_values_acc, new_delta_acc} ->
          case remove_all(get_variable(all_vars, idx), fixed_values_acc) do
            ## No new fixed variables
            false ->
              {unfixed_vars_acc, fixed_values_acc, new_delta_acc}

            new_fixed_value ->
              {Map.delete(unfixed_vars_acc, ref), MapSet.put(fixed_values_acc, new_fixed_value),
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

  defp get_value(variables, idx) do
    (idx && get_variable(variables, idx) |> min()) || nil
  end

  defp get_variable(variables, idx) do
    (idx && Enum.at(variables, idx)) || nil
  end
end
