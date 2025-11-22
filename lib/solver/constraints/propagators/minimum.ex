defmodule CPSolver.Propagator.Minimum do
  use CPSolver.Propagator

  @moduledoc """
  The propagator for Minimum constraint.
  minimum(y, x) constrains y to be a minimum of variables in the list x.
  """
  @spec new(Common.variable_or_view(), [Common.variable_or_view()]) :: Propagator.t()
  def new(min_var, vars) do
    new([min_var | vars])
  end

  @impl true
  def arguments(args) do
    Arrays.new(args, implementation: Aja.Vector)
  end

  @impl true
  def variables(vars) do
    Enum.map(vars, fn var -> set_propagate_on(var, :bound_change) end)
  end

  @impl true
  def filter(vars, state, changes) do
    if state do
      reduce_state(state, vars, changes)
    else
      initial_state(vars)
    end
    |> finalize(vars)
  end

  defp initial_state(vars) do
    array_length = Propagator.arg_size(vars) - 1
    %{
      active_var_indices: MapSet.new(1..array_length)
    }
    ## Initialize reduction by the 'min' variable change
    |> reduce_state(vars, %{0 => :bound_change})
  end

  defp finalize(state, vars) do
    if exists_fixed_to_min(state, vars) do
        :passive
    else
      {:state, state}
    end
  end

  defp exists_fixed_to_min(%{active_var_indices: active_var_indices} = _state, vars) do
    min_var = vars[0]
    if fixed?(min_var) do
      fixed_min = min(min_var)
      Enum.any?(active_var_indices, fn idx ->
        var = vars[idx]
        fixed?(var) && min(var) == fixed_min
      end)
    end
  end

  defp no_support?(_min_var, active_var_indices, _vars) do
    Enum.empty?(active_var_indices)
  end

  defp reduce_state(
    %{
      active_var_indices: active_var_indices,
      } = state, vars,
      _changes) do

    min_var = vars[0]

    min_max = min(min_var)
    max_max = max(min_var)

    {lb, ub, active_var_indices} =
      ## Try to reduce "array" variables

      Enum.reduce(active_var_indices, {nil, nil, active_var_indices}, fn idx, {min_acc, max_acc, active_acc} = _acc ->
        x_var = vars[idx]

        removeBelow(x_var, min_max)
        active_acc = if min(x_var) > max_max do
          ## The domain of the element is disjoint with domain of "max" variable.
          ## Hence we will ignore them
          MapSet.delete(active_acc, idx)
        else
          active_acc
        end

        x_min = min(x_var)
        x_max = max(x_var)

        {
          Kernel.min(min_acc || x_min, x_min),
          Kernel.min(max_acc || x_max, x_max),
          active_acc
        }
      end)

    ## If no "active" array variables (sucn that max(X) >= max(y)),
    ## then there is no support for y => failure
    if no_support?(min_var, active_var_indices, vars) do
      fail()
    end

    ## Reduce 'max' var
    removeAbove(min_var, ub)
    removeBelow(min_var, lb)

    ## Special case: if there is a unique element X
    ## that:
    ## a) has a support for max(min_var)
    ## b) max(X) > max(min_var)
    ##
    ##, then we can reduce it above max(min_var)
    ##
    try_reduce_x(min_var, vars, active_var_indices)

    state
    |> Map.put(:active_var_indices, active_var_indices)
  end

  defp try_reduce_x(min_var, vars, indices) do
    max_min_value = max(min_var)

    case Enum.reduce_while(indices, {false, nil}, fn idx, {found_support?, _supporting_idx} = acc ->
      if contains?(vars[idx], max_min_value) do
        if found_support? do
          ## More than one such element
          {:halt, {false, nil}}
        else
          ## First element
          {:cont, {true, idx}}
        end
      else
        {:cont, acc}
      end
    end) do
      {false, nil} -> false
      {true, supporting_idx} ->
        :no_change != removeAbove(vars[supporting_idx], max_min_value)
    end

  end

  defp fail() do
    throw(:fail)
  end

end
