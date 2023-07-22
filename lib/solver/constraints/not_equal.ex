defmodule CPSolver.Constraint.NotEqual do
  @behaviour CPSolver.Constraint
  alias CPSolver.Propagator.NotEqual
  def propagators(args) do
    [fn ->
      [x, y] = args
      NotEqual.filter(x, y) end]
  end
end
