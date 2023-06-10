defmodule CPSolver.Propagator do
  @callback variables() :: list()
  @callback filter() :: any()
end
