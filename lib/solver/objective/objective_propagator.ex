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
    removeAbove(x, Objective.get_bound(bound_handle))
  end
end
