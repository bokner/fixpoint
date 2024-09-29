defmodule CPSolver.Constraint.AllDifferent do
  use CPSolver.Constraint

  alias CPSolver.Constraint.AllDifferent.FWC, as: DefaultAllDifferent

  @impl true
  defdelegate propagators(x), to: DefaultAllDifferent
end
