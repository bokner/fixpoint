defmodule CPSolver.Constraint.Element2D do
  @moduledoc """
  Element2d constrains variables z, x and y such that:
  array2d[x][y] = z

  array2d is a regular (all rows are of the same length) list of lists of integers.
  """
  use CPSolver.Constraint
  alias CPSolver.Propagator.Element2D, as: Element2DPropagator
  alias CPSolver.IntVariable, as: Variable

  @spec new(
          [[integer()]],
          Variable.variable_or_view(),
          Variable.variable_or_view(),
          Variable.variable_or_view()
        ) :: Constraint.t()
  def new(arr2d, x, y, z) do
    new([arr2d, x, y, z])
  end

  @impl true
  def propagators(args) do
    [Element2DPropagator.new(args)]
  end

  @impl true
  def arguments([array2d, x, y, z]) when is_list(array2d) and is_list(hd(array2d)) do
    [array2d, Variable.to_variable(x), Variable.to_variable(y), Variable.to_variable(z)]
  end
end
