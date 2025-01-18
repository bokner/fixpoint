defmodule CPSolver.Constraint.AllDifferent.DC.Fast do
  use CPSolver.Constraint
  alias CPSolver.Propagator.AllDifferent.DC.Fast, as: Propagator

  @impl true
  def propagators(x) do
    [Propagator.new(x)]
  end
end
