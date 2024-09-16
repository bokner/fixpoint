defmodule CPSolver.Constraint.Count do
  @moduledoc """
  Constraints `c` to be the number of occurencies of `y` in `array`.

  """
  alias CPSolver.Constraint.Factory

  def new(array, y, c) do
    new([array, y, c])
  end

  def new([array, y, c] = _args) do
    Factory.count(array, y, c)
  end
end
