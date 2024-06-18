defmodule CPSolver.Constraint.Element do
  @moduledoc """
  Element constrains variables y and z such that:
  array[x] = y

  array is 1d list of integer constants
  """
  use CPSolver.Constraint
  alias CPSolver.Constraint.Element2D, as: Element2D
  alias CPSolver.IntVariable

  @spec new(
          [integer()],
          Variable.variable_or_view() | integer(),
          Variable.variable_or_view() | integer()
        ) :: Constraint.t()
  def new(array, x, y) do
    Element2D.new([[array], IntVariable.new(0), x, y])
  end

  @impl true
  def propagators(args) do
    Element2D.propagators(args)
  end

  @impl true
  def arguments([array, x, y]) when is_list(array) do
    [array, IntVariable.to_variable(x), IntVariable.to_variable(y)]
  end
end
