defmodule CPSolver.Objective.Propagator do
  alias CPSolver.Objective
  use CPSolver.Propagator

  def new(variable, bound_handle) do
    new([variable, bound_handle])
  end

  @impl true
  def variables([x | _rest]) do
    [set_propagate_on(x, :max_change)]
  end

  @impl true
  def filter([x, bound_handle | _], _state, _changes) do
    shared_bound = Objective.get_bound(bound_handle)
    maybe_update(x, shared_bound, bound_handle)
  end

  defp maybe_update(x, shared_bound, bound_handle) do
    max_x = max(x)

    cond do
      shared_bound < max_x ->
        removeAbove(x, shared_bound)
      shared_bound > max_x ->
        new_shared_bound = Objective.update_bound(bound_handle, max_x)
        maybe_update(x, new_shared_bound, bound_handle)
      true ->
        :ok
    end

  end
end
