defmodule CPSolver.Constraint.AllDifferent do
  use CPSolver.Constraint

  alias CPSolver.Constraint.AllDifferent.DC, as: DefaultAllDifferent

  @impl true
  defdelegate propagators(x), to: DefaultAllDifferent
end
