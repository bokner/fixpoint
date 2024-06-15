defmodule CPSolver.Constraint.LessOrEqual do
  use CPSolver.Constraint
  alias CPSolver.Propagator.LessOrEqual, as: LessOrEqualPropagator
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
    [LessOrEqualPropagator.new(args)]
  end

  @impl true
  def arguments([x, y, offset]) do
    [Variable.to_variable(x), Variable.to_variable(y), offset]
  end
end
