defmodule CPSolver.Constraint.AllDifferent.FWC do
  use CPSolver.Constraint
  alias CPSolver.Propagator.AllDifferent.FWC, as: FWCPropagator

  @impl true
  def propagators(x) do
    [FWCPropagator.new(x)]
  end
end
