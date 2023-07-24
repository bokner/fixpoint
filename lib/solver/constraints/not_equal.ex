defmodule CPSolver.Constraint.NotEqual do
  use CPSolver.Constraint
  alias CPSolver.Propagator.NotEqual, as: NotEqualPropagator

  def propagators(_args) do
    [NotEqualPropagator]
  end

  def variables(args) do
    args
  end
end
