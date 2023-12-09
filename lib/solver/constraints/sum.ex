defmodule CPSolver.Constraint.Sum do
  use CPSolver.Constraint
  alias CPSolver.Propagator.Sum, as: SumPropagator

  @spec new(Variable.variable_or_view(), [Variable.variable_or_view()]) :: Constraint.t()
  def new(y, x) do
    new([y | x])
  end

  @impl true
  def propagators([y | x]) do
    [SumPropagator.new(y, x)]
  end
end
