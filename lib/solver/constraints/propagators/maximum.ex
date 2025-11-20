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
    %{
      x_min: nil,
      x_max: nil,
      array_length: Propagator.arg_size(vars) - 1,
      variables: vars
    }
    ## Initialize reduction by the 'max' variable change
    |> reduce_state(%{0 => :bound_change})
  end

  defp finalize(state) do
    :todo
  end

  defp reduce_state(
         %{array_length: l, variables: vars, x_min: x_min, x_max: x_max} = state,
         changes \\ %{}
       ) do
    max_var = vars[0]

    {reduce_array_vars?, max_max} =
      if Map.has_key?(changes, 0) do
        {true, max(max_var)}
      else
        {false, nil}
      end

    {new_lb, new_ub} =
      Enum.reduce(1..l, {x_min, x_max}, fn idx, {min_acc, max_acc} = acc ->
        ## If the 'max' variable changed, reduce 'array' vars
        x_var = vars[idx]

        if reduce_array_vars? do
          removeAbove(x_var, max_max)
        end

        x_min = min(x_var)
        x_max = max(x_var)

        new_acc = {
          Kernel.max(min_acc || x_min, x_min),
          Kernel.max(max_acc || x_max, x_max)
        }
      end)

    ## Reduce 'max' var
    if is_nil(x_max) || new_ub < x_max do
      removeAbove(max_var, new_ub)
    end

    if is_nil(x_min) || new_lb > x_min do
      removeBelow(max_var, new_lb)
    end

    state
    |> Map.put(:x_max, new_ub)
    |> Map.put(:x_min, new_lb)
  end
end
