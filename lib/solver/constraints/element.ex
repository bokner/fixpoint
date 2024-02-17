defmodule CPSolver.Constraint.Element do
  @moduledoc """
  Element constrains variables y and z such that:
  array[y] = z
  """
  use CPSolver.Constraint
  alias CPSolver.Constraint.Element2D, as: Element2D
  alias CPSolver.IntVariable

  @spec new(
          [integer()],
          Variable.variable_or_view(),
          Variable.variable_or_view()
        ) :: Constraint.t()
  def new(array, y, z) do
    Element2D.new([[array], IntVariable.new(0), y, z])
  end

  @impl true
  def propagators(args) do
    Element2D.propagators(args)
  end
end
