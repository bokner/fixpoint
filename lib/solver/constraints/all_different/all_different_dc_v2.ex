defmodule CPSolver.Constraint.AllDifferent.DC.V2 do
  use CPSolver.Constraint
  alias CPSolver.Propagator.AllDifferent.DC.V2, as: Propagator

  @impl true
  def propagators(x) do
    [Propagator.new(x)]
  end
end
