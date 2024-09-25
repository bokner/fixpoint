defmodule CPSolver.Constraint.Sum do
  use CPSolver.Constraint
  alias CPSolver.Propagator.Sum, as: SumPropagator
  alias CPSolver.Variable.View.Factory
  alias CPSolver.IntVariable, as: Variable

  @spec new(Variable.variable_or_view(), [Variable.variable_or_view()]) :: Constraint.t()

  def new(c, x) when is_integer(c) do
    new(Variable.new(c), x)
  end

  def new(y, x) do
    new([y | x])
  end

  @impl true
  def propagators([y | x]) do
    # Separate constants and variables
    {constant, vars} =
      List.foldr(x, {0, []}, fn arg, {constant_acc, vars_acc} ->
        (is_integer(arg) && {constant_acc + arg, vars_acc}) ||
          {constant_acc, [arg | vars_acc]}
      end)

    ## Adjust sum (variable or constant)
    y_arg =
      (is_integer(y) && Variable.new(y - constant)) ||
        Factory.inc(y, -constant)

    [SumPropagator.new(y_arg, vars)]
  end
end
