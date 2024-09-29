defmodule CPSolver.Constraint.Equal do
  use CPSolver.Constraint
  alias CPSolver.Propagator.Equal, as: EqualPropagator

  def new(x, y, offset \\ 0)

  def new(x, y, offset) do
    new([x, y, offset])
  end

  @impl true
  def propagators(args) do
    [EqualPropagator.new(args)]
  end
end
