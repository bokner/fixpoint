defmodule CPSolver.Constraint.Element2D do
  @moduledoc """
  Element2d constrains variables z, x and y such that:
  array2d[x][y] = z
  """
  use CPSolver.Constraint
  alias CPSolver.Propagator.Element2D, as: Element2DPropagator

  @impl true
  def propagators(args) do
    [Element2DPropagator.new(args)]
  end
end
