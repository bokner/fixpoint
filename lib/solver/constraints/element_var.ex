defmodule CPSolver.Constraint.ElementVar do
  @moduledoc """
  ElementVar constrains list of variables `array`, variables `x` and `y` such that:
  array[x] = y

  array is a list of variables
  """
  use CPSolver.Constraint
  alias CPSolver.Propagator.ElementVar, as: ElementVarPropagator
  alias CPSolver.IntVariable, as: Variable

  @spec new(
          [Variable.variable_or_view()],
          Variable.variable_or_view(),
          Variable.variable_or_view()
        ) :: Constraint.t()
  def new(array, x, y) do
    new([array, x, y])
  end

  @impl true
  def propagators(args) do
    [ElementVarPropagator.new(args)]
  end

  @impl true
  def arguments([array, x, y]) when is_list(array) do
    [Enum.map(array, &Variable.to_variable/1), Variable.to_variable(x), Variable.to_variable(y)]
  end
end
