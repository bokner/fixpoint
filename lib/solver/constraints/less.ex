defmodule CPSolver.Constraint.Less do
  use CPSolver.Constraint
  alias CPSolver.Constraint.LessOrEqual, as: LessOrEqual

  def new(x, y, offset \\ 0) do
    LessOrEqual.new(le_args([x, y, offset]))
  end

  @impl true
  def propagators(args) do
    LessOrEqual.propagators(le_args(args))
  end

  @impl true
  def arguments(args) do
    LessOrEqual.arguments(args)
  end

  defp le_args([x, y | offset]) do
    [x, y, (List.first(offset) || 0) - 1]
  end
end
