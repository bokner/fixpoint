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
    unfixed_set = state && state[:unfixed] || MapSet.new(0..Arrays.size(all_vars) - 1)
    case fwc(all_vars, unfixed_set, fixed_values(changes, all_vars)) do
      nil -> :passive
      unfixed_updated_set -> {:state, %{unfixed: unfixed_updated_set}}
    end
  end

  defp fixed_values(changes, arg_vars) do
    Enum.reduce(changes, MapSet.new(), fn {var_idx, :fixed}, acc ->
      MapSet.put(acc, min(Propagator.arg_at(arg_vars, var_idx)))

    end)
  end


  ## unfixed_set - set of indices for yet unfixed variables
  ## fixed_values - the set of fixed values we will use to reduce unfixed set.
  defp fwc(vars, unfixed_set, fixed_values) do
    {reduced_unfixed, step_fixed, _total_fixed} =
    Enum.reduce(unfixed_set, {MapSet.new(), MapSet.new(), fixed_values},
      fn unfixed_idx, {reduced_unfixed_acc, step_fixed_acc, total_fixed_acc} ->
        var = Propagator.arg_at(vars, unfixed_idx)
        if remove_all(var, total_fixed_acc) == :fixed do
          ## New fixed variable, add to fixed values
          new_fixed_value = min(var)
          {reduced_unfixed_acc,
            MapSet.put(total_fixed_acc, new_fixed_value),
            MapSet.put(total_fixed_acc, new_fixed_value)
          }
        else
          ## Still unfixed, add to unfixed set
          {MapSet.put(reduced_unfixed_acc, unfixed_idx),
            step_fixed_acc,
            total_fixed_acc
          }
        end
      end)

    cond do
      MapSet.size(reduced_unfixed) <= 1 -> nil
      MapSet.size(step_fixed) == 0 -> reduced_unfixed
      true ->
        fwc(vars, reduced_unfixed, step_fixed)
      end
  end

  defp remove_all(var, values) do
    Enum.reduce_while(values, nil, fn val, _acc ->
      remove(var, val) == :fixed && {:halt, :fixed}
      || {:cont, nil}
    end)
  end


end
