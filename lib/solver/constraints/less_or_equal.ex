defmodule CPSolver.Constraint.LessOrEqual do
  use CPSolver.Constraint
  alias CPSolver.Propagator.LessOrEqual, as: LessOrEqualPropagator

  def new(x, y, offset \\ 0) do
    new([x, y, offset])
  end

  @impl true
  def propagators(args) do
    [LessOrEqualPropagator.new(args)]
  end
end
