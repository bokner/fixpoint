defmodule CPSolver.Constraint.NotEqual do
  use CPSolver.Constraint
  alias CPSolver.Propagator.NotEqual, as: NotEqualPropagator

  def new(x, y, offset \\ 0)

  def new(x, y, offset) do
    new([x, y, offset])
  end

  @impl true
  def propagators(args) do
    [NotEqualPropagator.new(args)]
  end
end
