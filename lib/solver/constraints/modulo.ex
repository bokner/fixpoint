defmodule CPSolver.Constraint.Modulo do
  use CPSolver.Constraint
  alias CPSolver.Propagator.Modulo, as: ModuloPropagator
  alias CPSolver.IntVariable, as: Variable

  def new(m, x, y)

  def new(m, x, y) do
    new([m, x, y])
  end

  @impl true
  def arguments(args) do
    Enum.map(args, fn arg -> (is_integer(arg) && Variable.new(arg)) || arg end)
  end

  @impl true
  def propagators(args) do
    [ModuloPropagator.new(args)]
  end
end
