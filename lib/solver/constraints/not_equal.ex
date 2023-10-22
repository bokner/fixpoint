defmodule CPSolver.Constraint.NotEqual do
  use CPSolver.Constraint
  alias CPSolver.Propagator.NotEqual, as: NotEqualPropagator

  @impl true
  def propagators(args) do
    [NotEqualPropagator.new(args)]
  end
end
