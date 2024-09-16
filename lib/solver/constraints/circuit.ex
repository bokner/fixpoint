defmodule CPSolver.Constraint.Circuit do
  use CPSolver.Constraint
  alias CPSolver.Propagator.Circuit, as: CircuitPropagator

  @impl true
  def propagators(x) do
    [CircuitPropagator.new(x)]
  end
end
