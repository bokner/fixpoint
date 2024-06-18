defmodule CPSolver.Constraint.Absolute do
  @moduledoc """
  Absolute value constraint.
  Costraints y to be |x|
  """
  use CPSolver.Constraint
  alias CPSolver.Propagator.Absolute, as: AbsolutePropagator
  alias CPSolver.IntVariable

  def new(x, y) do
    new([x, y])
  end

  @impl true
  def propagators(args) do
    [AbsolutePropagator.new(args)]
  end

  @impl true
  def arguments([x, y]) do
    [IntVariable.to_variable(x), IntVariable.to_variable(y)]
  end
end
