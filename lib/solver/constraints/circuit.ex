defmodule CPSolver.Constraint.Circuit do
  use CPSolver.Constraint
  alias CPSolver.Propagator.Circuit, as: CircuitPropagator

  @impl true
  def propagators(x) do
    [CircuitPropagator.new(x), CPSolver.Propagator.AllDifferent.DC.new(x)]
  end
end
