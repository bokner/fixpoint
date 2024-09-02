defmodule CPSolver.Propagator.Less do
  alias CPSolver.Propagator.LessOrEqual, as: LessOrEqual

  # def new(x, y, offset \\ 0) do
  #   LessOrEqual.new(x, y, offset - 1)
  # end

  defdelegate variables(args), to: LessOrEqual
  defdelegate filter(args), to: LessOrEqual
  defdelegate filter(args, state), to: LessOrEqual

  def filter(args, state, changes) do
    LessOrEqual.filter(le_args(args), state, changes)
  end

  def entailed?(args, state) do
    LessOrEqual.entailed?(le_args(args), state)
  end

  def failed?(args, state) do
    LessOrEqual.failed?(le_args(args), state)
  end

  defp le_args([x, y]) do
    le_args([x, y, 0])
  end

  defp le_args([x, y, offset]) do
    [x, y, offset - 1]
  end
end
