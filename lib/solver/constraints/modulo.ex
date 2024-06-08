defmodule CPSolver.Constraint.Modulo do
  use CPSolver.Constraint
  alias CPSolver.Propagator.Modulo, as: ModuloPropagator

  def new(m, x, y)

  def new(m, x, y) do
    new([m, x, y])
  end

  @impl true
  def propagators(args) do
    [ModuloPropagator.new(args)]
  end
end
