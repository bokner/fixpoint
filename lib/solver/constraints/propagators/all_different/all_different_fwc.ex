defmodule CPSolver.Propagator.AllDifferent.FWC do
  use CPSolver.Propagator

  @moduledoc """
  The forward-checking propagator for AllDifferent constraint.
  """

  @impl true
  def arguments(args) do
    Arrays.new(args, implementation: Aja.Vector)
  end

  @impl true
  def variables(args) do
    Enum.map(args, fn x_el -> set_propagate_on(x_el, :fixed) end)
  end

  @impl true
  def filter(all_vars, state, changes) do
    new_fixed = Map.keys(changes) |> MapSet.new()

    {unresolved, fixed} =
      (state &&
         {state[:unresolved] |> MapSet.difference(new_fixed), fixed_values(all_vars, new_fixed)}) ||
        initial_split(all_vars)

    case fwc(all_vars, unresolved, fixed) do
      false -> :passive
      unfixed_updated_set -> {:state, %{unresolved: unfixed_updated_set}}
    end
  end

  defp fixed_values(vars, fixed) do
    Enum.reduce(fixed, MapSet.new(), fn idx, values_acc ->
      val = Propagator.arg_at(vars, idx) |> min()
      (val in values_acc && fail()) || MapSet.put(values_acc, val)
    end)
  end

  defp initial_split(vars) do
    Enum.reduce(0..(Arrays.size(vars) - 1), {MapSet.new(), MapSet.new()}, fn idx,
                                                                             {unfixed_acc,
                                                                              fixed_vals_acc} ->
      var = Propagator.arg_at(vars, idx)

      if fixed?(var) do
        val = min(var)
        (val in fixed_vals_acc && fail()) || {unfixed_acc, MapSet.put(fixed_vals_acc, val)}
      else
        {MapSet.put(unfixed_acc, idx), fixed_vals_acc}
      end
    end)
  end

  defp fwc(vars, unfixed_set, fixed_values) do
    {updated_unfixed, updated_fixed_vals} = remove_values(vars, unfixed_set, fixed_values)
    MapSet.size(updated_unfixed) > 1 &&
    (
      fv_diff = MapSet.difference(updated_fixed_vals, fixed_values)
      MapSet.size(fv_diff) > 0 &&
       fwc(vars, updated_unfixed, fv_diff) || updated_unfixed
    )
  end

  ## unfixed_set - set of indices for yet unfixed variables
  ## fixed_values - the set of fixed values we will use to reduce unfixed set.
  defp remove_values(vars, unfixed_set, fixed_values) do
    for idx <- unfixed_set, reduce: {MapSet.new(), fixed_values} do
      {still_unfixed_acc, fixed_vals_acc} ->
        var = Propagator.arg_at(vars, idx)

        case remove_all(var, fixed_vals_acc) do
          false ->
            ## Variable is still unfixed, keep it
            {MapSet.put(still_unfixed_acc, idx), fixed_vals_acc}

          new_fixed_value ->
            fixed_vals_acc = MapSet.put(fixed_vals_acc, new_fixed_value)

            {unfixed_here, fixed_here} =
              remove_values(vars, still_unfixed_acc, MapSet.new([new_fixed_value]))

            {unfixed_here, MapSet.union(fixed_here, fixed_vals_acc)}
        end
    end
  end

  defp remove_all(var, values) do
    Enum.reduce_while(values, false, fn val, acc ->
      if remove(var, val) == :fixed do
        {:halt, :fixed}
      else
        {:cont, acc}
      end
    end)
    |> case do
      false ->
        fixed?(var) && min(var)

      :fixed ->
        min(var)
    end
    |> then(fn new_min -> new_min && ((new_min in values && fail()) || new_min) end)
  end

  defp fail() do
    throw(:fail)
  end
end
