defmodule CPSolver.Model do
  alias CPSolver.Constraint
  @callback constraints() :: [Constraint.t()]
end
