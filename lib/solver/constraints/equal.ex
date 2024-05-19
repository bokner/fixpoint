defmodule CPSolver.Constraint.Equal do
  use CPSolver.Constraint
  alias CPSolver.Propagator.Equal, as: EqualPropagator
  alias CPSolver.IntVariable, as: Variable

  def new(x, y, offset \\ 0)

  def new(x, y, offset) when is_integer(y) do
    new(x, Variable.new(y), offset)
  end

  def new(x, y, offset) do
    new([x, y, offset])
  end

  @impl true
  def propagators(args) do
    [EqualPropagator.new(args)]
  end
end
