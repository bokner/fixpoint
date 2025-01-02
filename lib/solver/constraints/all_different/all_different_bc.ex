defmodule CPSolver.Constraint.AllDifferent.BC do
  use CPSolver.Constraint
  alias CPSolver.Propagator.AllDifferent.BC, as: Propagator

  @impl true
  def propagators(x) do
    [Propagator.new(x)]
  end
end
