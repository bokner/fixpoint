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
      reduce_state(state, changes)
    else
      initial_state(vars)
    end
    |> finalize()
  end

  defp initial_state(vars) do
    array_length = Propagator.arg_size(vars) - 1
    %{
      x_min: nil,
      x_max: nil,
      active_var_indices: MapSet.new(1..array_length),
      variables: vars
    }
    ## Initialize reduction by the 'max' variable change
    |> reduce_state(%{0 => :bound_change})
  end

  defp finalize(%{variables: vars} = state) do
    if fixed?(vars[0]) do
      :passive
    else
      {:state, state}
    end
  end

  defp reduce_state(
    %{
      x_min: x_min,
      x_max: x_max,
      active_var_indices: active_var_indices,
      variables: vars,
      } = state,
      _changes) do

    max_var = vars[0]

    min_max = min(max_var)
    max_max = max(max_var)

    {lb, ub, active_var_indices} =
      ## Try to reduce "array" variables

      Enum.reduce(active_var_indices, {x_min, x_max, active_var_indices}, fn idx, {min_acc, max_acc, active_acc} = _acc ->
        x_var = vars[idx]

        removeAbove(x_var, max_max)
        active_acc = if max(x_var) < min_max do
          ## The domain of the element is disjoint with domain of "max" variable.
          ## Hence we don't look at it anymore
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
    if MapSet.size(active_var_indices) == 0 do
      fail()
    end

    ## Reduce 'max' var
    if is_nil(x_max) || ub < x_max do
      removeAbove(max_var, ub)
    end

    if is_nil(x_min) || lb > x_min do
      removeBelow(max_var, lb)
    end

    ## Special case: if there is a unique element X
    ## that:
    ## a) has a support for min(max_var)
    ## b) min(X) < min(max_var)
    ##
    ##, then we can reduce it below min(max_var)
    ##
    try_reduce_x(max_var, vars, active_var_indices)

    state
    |> Map.put(:x_max, ub)
    |> Map.put(:x_min, lb)
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
      {false, nil} -> :ok
      {true, supporting_idx} ->
        removeBelow(vars[supporting_idx], min_max_var)
    end

  end

  defp fail() do
    throw(:fail)
  end

end
