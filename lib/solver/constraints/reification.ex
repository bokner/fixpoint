defmodule CPSolver.Constraint.Reified do
  @moduledoc """
  Reified (equivalence) constraint.
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
    [reified_propagator(constraint, b, :full)]
  end

  def reified_propagator(constraint, b, mode) when mode in [:full, :half, :inverse_half] do
    ReifPropagator.new(Constraint.constraint_to_propagators(constraint), b, mode)
  end

  @impl true
  def arguments([{constraint_impl, args} = constraint, b])
      when is_atom(constraint_impl) and is_list(args) do
    [constraint, IntVariable.to_variable(b)]
  end
end

defmodule CPSolver.Constraint.HalfReified do
  @moduledoc """
  Half-reified (implication) constraint.
  Extends constraint C to constraint R(C, b),
  where 'b' is a boolean variable, and
  b is fixed to true if C holds
  """
  alias CPSolver.Constraint.Reified

  defdelegate new(constraint, b), to: Reified
  defdelegate arguments(args), to: Reified

  @impl true
  def propagators([constraint, b]) do
    [Reified.reified_propagator(constraint, b, :half)]
  end

end

defmodule CPSolver.Constraint.InverseImplication do
  @moduledoc """
  Inverse half-reified (inverse implication) constraint.
  Extends constraint C to constraint R(C, b),
  where 'b' is a boolean variable, and
  C holds if b is fixed to true.
  """
  alias CPSolver.Constraint.Reified

  defdelegate new(constraint, b), to: Reified
  defdelegate arguments(args), to: Reified

  @impl true
  def propagators([constraint, b]) do
    [Reified.reified_propagator(constraint, b, :inverse_half)]
  end

end
