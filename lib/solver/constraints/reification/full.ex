defmodule CPSolver.Constraint.Reified.Full do
  @moduledoc """
  Reified constraint.
  Extends constraint C to constraint R(C, b),
  where 'b' is a boolean variable, and
  C holds iff b is fixed to true
  """
  use CPSolver.Constraint
  alias CPSolver.Propagator.Reified, as: ReifPropagator
  alias CPSolver.IntVariable

  def new(constraint, b) do
    new([constraint, b])
  end

  @impl true
  def propagators([constraint, b]) do
    [ReifPropagator.new(constraint, b, :full)]
  end

  @impl true
  def arguments([{constraint_impl, args} = constraint, y])
      when is_atom(constraint_impl) and is_list(args) do
    [constraint, IntVariable.to_variable(y)]
  end
end
