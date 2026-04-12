defmodule CPSolver.Propagator.Channel do
  use CPSolver.Propagator

  @impl true
  def variables([x | b]) do
    [
      set_propagate_on(x, :domain_change) |
      Enum.map(b, fn b_var -> set_propagate_on(b_var, :fixed) end)
    ]
  end

  @impl true
  def arguments(args) do
    Vector.new(args)
  end

  @impl true
  def filter(vars, state, changes) do
    if state do
      update_state(state, vars)
    else
     initial_state(vars)
    end
    |> reduce_state(changes)
    |> finalize()
  end

  defp initial_state(vars) do
    :todo
  end

  defp update_state(state, vars) do
    :todo
  end

  defp reduce_state(state, changes) do
    :todo
  end

  defp finalize(state) do
    :todo
  end

end
