defmodule CPSolver.Constraint.Maximum do
  use CPSolver.Constraint
  alias CPSolver.Propagator.Maximum, as: MaximumPropagator
  alias CPSolver.IntVariable, as: Variable

  @spec new(Variable.variable_or_view(), [Variable.variable_or_view()]) :: Constraint.t()

  def new(c, x) when is_integer(c) do
    new(Variable.new(c), x)
  end

  def new(y, x) do
    new([y | x])
  end

  @impl true
  def propagators([_max_var | _var_list] = vars) do
    [MaximumPropagator.new(vars)]
  end
end
