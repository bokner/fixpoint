defmodule CPSolver.Constraint.AllDifferent.Combined do
  use CPSolver.Constraint

  #alias CPSolver.Constraint.AllDifferent.FWC, as: DefaultAllDifferent

  @impl true
  def propagators(x) do
    [
      CPSolver.Propagator.AllDifferent.DC.new(x),
      CPSolver.Propagator.AllDifferent.FWC.new(x)
    ]
  end
end
