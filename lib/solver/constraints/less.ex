defmodule CPSolver.Constraint.Less do
  use CPSolver.Constraint
  alias CPSolver.Constraint.LessOrEqual, as: LessOrEqual

  def new(x, y, offset \\ 0) do
    LessOrEqual.new(x, y, offset - 1)
  end

  @impl true
  def propagators(args) do
    LessOrEqual.new(args)
  end
end
