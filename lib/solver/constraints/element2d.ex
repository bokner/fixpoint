defmodule CPSolver.Constraint.Element2D do
  @moduledoc """
  Element2d constrains variables z, x and y such that:
  array2d[x][y] = z
  """
  use CPSolver.Constraint
  alias CPSolver.Propagator.Element2D, as: Element2DPropagator

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
end
