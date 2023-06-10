defmodule CPSolver.Constraint do
  @callback post() :: boolean()
  @callback propagate() :: boolean()
end
