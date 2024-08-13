defmodule CPSolver.Propagator.Less do
  alias CPSolver.Propagator.LessOrEqual, as: LessOrEqual

  def new(x, y, offset \\ 0) do
    LessOrEqual.new(x, y, offset - 1)
  end

  defdelegate variables(args), to: LessOrEqual
  defdelegate filter(args, state), to: LessOrEqual
  defdelegate filter(args, state, changes), to: LessOrEqual
  defdelegate resolved?(args, state), to: LessOrEqual
  defdelegate failed?(args, state), to: LessOrEqual


end
