defmodule CPSolver.Constraint.Sum do
  use CPSolver.Constraint
  alias CPSolver.Propagator.Sum, as: SumPropagator

  def new(x, y, offset \\ 0) do
    new([x, y, offset])
  end

  @impl true
  def propagators(args) do
    [SumPropagator.new(args)]
  end
end
