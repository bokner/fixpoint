defmodule CPSolver.Constraint.AllDifferent.DC do
  use CPSolver.Constraint
  alias CPSolver.Propagator.AllDifferent.DC, as: Propagator

  @impl true
  def propagators(x) do
    [Propagator.new(x)]
  end
end
