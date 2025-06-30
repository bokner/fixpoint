defmodule CPSolver.Propagator.Sum2 do
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
    Arrays.new(args, implementation: Aja.Vector)
  end

  defp initial_state(args) do
    {_idx, minimums, maximums, sum_min, sum_max} =
      args
      |> Enum.reduce({0, Map.new(), Map.new(), 0, 0}, fn var,
                                                         {idx_acc, mins_acc, maxes_acc,
                                                          sum_min_acc, sum_max_acc} ->
        next_idx = idx_acc + 1
        min = min(var)
        max = max(var)

        {next_idx, Map.put(mins_acc, idx_acc, min), Map.put(maxes_acc, idx_acc, max),
         sum_min_acc + min, sum_max_acc + max}
      end)

    (unsatisfiable?(sum_min, sum_max) && fail()) ||
      %{minimums: minimums, maximums: maximums, sum_min: sum_min, sum_max: sum_max}
  end

  @impl true
  def variables([y | x]) do
    [
      set_propagate_on(y, :bound_change)
      | Enum.map(x, fn x_el -> set_propagate_on(x_el, :bound_change) end)
    ]
  end

  @impl true
  def filter(all_vars, nil, changes) do
    filter(all_vars, initial_state(all_vars), changes)
  end

  def filter(vars, state, changes) when map_size(changes) > 0 do
    updated_state =
      Enum.reduce(changes, state, fn
        {pos, domain_change}, state_acc ->
          var = Arrays.get(vars, pos)
          update_state_impl(var, pos, domain_change, state_acc)
      end)

    (unsatisfiable?(updated_state) && fail()) ||
      {:state, updated_state}

    ## TODO: cut variables according to new partial sums
  end

  def filter(vars, state, changes) when map_size(changes) == 0 do
    (state && state) || initial_state(vars)
  end

  defp update_state_impl(var, pos, :min_change, %{sum_min: sum_min, minimums: mins} = state) do
    new_min = min(var)
    current_min = Map.get(mins, pos)
    %{state | sum_min: sum_min + new_min - current_min, minimums: Map.put(mins, pos, new_min)}
  end

  defp update_state_impl(var, pos, :max_change, %{sum_max: sum_max, maximums: maxes} = state) do
    new_max = max(var)
    current_max = Map.get(maxes, pos)
    %{state | sum_max: sum_max + new_max - current_max, maximums: Map.put(maxes, pos, new_max)}
  end

  defp update_state_impl(
         var,
         pos,
         domain_change,
         %{
           sum_min: sum_min,
           minimums: mins,
           sum_max: sum_max,
           maximums: maxes
         } = state
       )
       when domain_change in [:fixed, :bound_change] do
    fixed_value = min(var)
    current_max = Map.get(maxes, pos)
    current_min = Map.get(mins, pos)

    %{
      state
      | sum_max: sum_max + fixed_value - current_max,
        maximums: Map.put(maxes, pos, fixed_value),
        sum_min: sum_min + fixed_value - current_min,
        minimums: Map.put(mins, pos, fixed_value)
    }
  end

  defp update_state_impl(_var, _pos, _domain_change, state) do
    state
  end

  defp unsatisfiable?(sum_min, sum_max) do
    sum_min > 0 || sum_max < 0
  end

  defp unsatisfiable?(%{sum_min: sum_min, sum_max: sum_max} = _state) do
    unsatisfiable?(sum_min, sum_max)
  end

  defp fail() do
    throw(:fail)
  end
end
