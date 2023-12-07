defmodule CPSolver.Constraint.Sum do
  use CPSolver.Constraint
  alias CPSolver.Propagator.Sum, as: SumPropagator

  @spec new(Variable.variable_or_view(), Variable.variable_or_view()) :: Propagator.t()
  def new(x, y) do
    new([x, y])
  end

  @impl true
  def propagators(args) do
    [SumPropagator.new(args)]
  end
end
