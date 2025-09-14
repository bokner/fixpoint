defmodule CPSolver.Constraint.Circuit do
  use CPSolver.Constraint
  alias CPSolver.Propagator.Circuit, as: CircuitPropagator

  @impl true
  def propagators(x) do
    [
      CPSolver.Propagator.AllDifferent.DC.Fast.new(x),
      CircuitPropagator.new(x)]
  end
end
