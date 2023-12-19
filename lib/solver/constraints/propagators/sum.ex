defmodule CPSolver.Propagator.Sum do
  use CPSolver.Propagator
  import CPSolver.Variable.View.Factory

  @moduledoc """
  The propagator for Sum constraint.
  Sum(y, x) constrains y to be a sum of variables in the list x.
  """
  @spec new(Common.variable_or_view(), [Common.variable_or_view()]) :: Propagator.t()
  def new(y, x) do
    args = [minus(y) | x]

    new(args)
    |> Map.put(:state, initial_state(args))
  end

  defp initial_state(args) do
    {sum_fixed, unfixed_vars} =
      Enum.reduce(args, {0, %{}}, fn arg, {sum_acc, unfixed_acc} ->
        var = Interface.variable(arg)

        (var.fixed? && {sum_acc + Interface.min(arg), unfixed_acc}) ||
          {sum_acc, Map.put(unfixed_acc, var.id, arg)}
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

  @impl true
  def filter(all_vars, %{sum_fixed: sum_fixed, unfixed_vars: unfixed_vars} = _state) do
    unfixed_vars = Enum.filter(all_vars, fn v -> Map.has_key?(unfixed_vars, Interface.id(v)) end)
    {sum_min, sum_max} = sum_min_max(sum_fixed, unfixed_vars)
    filter_impl(all_vars, sum_min, sum_max)
  end

  defp filter_impl(_variables, sum_min, sum_max) when sum_min > 0 or sum_max < 0 do
    :fail
  end

  defp filter_impl(variables, sum_min, sum_max) do
    {new_sum_min, new_sum_max} =
      Enum.reduce(variables, {0, 0}, fn v, {s_min, s_max} ->
        min_v = min(v)
        max_v = max(v)

        removeAbove(v, -(sum_min - min_v))
        removeBelow(v, -(sum_max - max_v))
        {s_min + min(v), s_max + max(v)}
      end)

    ## Enforce idempotence: we'll run filtering until there's no changes
    ((new_sum_min != sum_min ||
        new_sum_max != sum_max) && filter_impl(variables, new_sum_min, new_sum_max)) ||
      :ok
  end

  defp sum_min_max(sum_fixed, unfixed_variables) do
    Enum.reduce(unfixed_variables, {sum_fixed, sum_fixed}, fn v, {s_min, s_max} = _acc ->
      {s_min + min(v), s_max + max(v)}
    end)
  end

  @impl true
  def update(%{state: state} = sum_propagator, changes) do
    new_state =
      Enum.reduce(changes, state, fn
        {var_id, :fixed}, %{sum_fixed: sum_fixed, unfixed_vars: unfixed_vars} = acc ->
          case Map.get(unfixed_vars, var_id) do
            nil ->
              acc

            var ->
              fixed_value = min(var)
              new_sum = fixed_value + sum_fixed
              new_unfixed_vars = Map.delete(unfixed_vars, var_id)

              acc
              |> Map.put(:sum_fixed, new_sum)
              |> Map.put(:unfixed_vars, new_unfixed_vars)
          end

        _, acc ->
          acc
      end)

    Map.put(sum_propagator, :state, new_state)
  end
end
