defmodule CPSolver.Constraint.NotEqual do
  @behaviour CPSolver.Constraint
  alias CPSolver.Propagator.NotEqual

  def propagators(args) do
    [
      fn ->
        NotEqual.filter(args)
      end
    ]
  end
end
