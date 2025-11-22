defmodule CPSolver.Propagator.Maximum do
  use CPSolver.Propagator

  @moduledoc """
  The propagator for Maximum constraint.
  maximum(y, x) constrains y to be a maximum of variables in the list x.
  """
  @spec new(Common.variable_or_view(), [Common.variable_or_view()]) :: Propagator.t()
  def new(max_var, vars) do
    new([max_var | vars])
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
      x_min: nil,
      x_max: nil,
      active_var_indices: MapSet.new(1..array_length)
    }
    ## Initialize reduction by the 'max' variable change
    |> reduce_state(vars, %{0 => :bound_change})
  end

  defp finalize(state, vars) do
    max_var = vars[0]
    if fixed?(max_var) && exists_fixed_to_max(max_var, state, vars) do
        :passive
    else
      {:state, state}
    end
  end

  defp exists_fixed_to_max(max_var, %{active_var_indices: active_var_indices} = _state, vars) do
    fixed_max = min(max_var)
    Enum.any?(active_var_indices, fn idx ->
      var = vars[idx]
      fixed?(vars) && min(var) == fixed_max
    end)
  end

  defp no_support?(_max_var, active_var_indices, _vars) do
    Enum.empty?(active_var_indices)
  end

  defp reduce_state(
    %{
      active_var_indices: active_var_indices,
      } = state, vars,
      _changes) do

    max_var = vars[0]

    min_max = min(max_var)
    max_max = max(max_var)

    {lb, ub, active_var_indices} =
      ## Try to reduce "array" variables

      Enum.reduce(active_var_indices, {nil, nil, active_var_indices}, fn idx, {min_acc, max_acc, active_acc} = _acc ->
        x_var = vars[idx]

        removeAbove(x_var, max_max)
        active_acc = if max(x_var) < min_max do
          ## The domain of the element is disjoint with domain of "max" variable.
          ## Hence we will ignore them
          MapSet.delete(active_acc, idx)
        else
          active_acc
        end

        x_min = min(x_var)
        x_max = max(x_var)

        {
          Kernel.max(min_acc || x_min, x_min),
          Kernel.max(max_acc || x_max, x_max),
          active_acc
        }
      end)

    ## If no "active" array variables (sucn that max(X) >= max(y)),
    ## then there is no support for y => failure
    if no_support?(max_var, active_var_indices, vars) do
      fail()
    end

    ## Reduce 'max' var
    removeAbove(max_var, ub)
    removeBelow(max_var, lb)

    ## Special case: if there is a unique element X
    ## that:
    ## a) has a support for min(max_var)
    ## b) min(X) < min(max_var)
    ##
    ##, then we can reduce it below min(max_var)
    ##
    try_reduce_x(max_var, vars, active_var_indices)

    state
    |> Map.put(:active_var_indices, active_var_indices)
  end

  defp try_reduce_x(max_var, vars, indices) do
    min_max_var = min(max_var)

    case Enum.reduce_while(indices, {false, nil}, fn idx, {found_support?, _supporting_idx} = acc ->
      if contains?(vars[idx], min_max_var) do
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
        :no_change != removeBelow(vars[supporting_idx], min_max_var)
    end

  end

  defp fail() do
    throw(:fail)
  end

end
