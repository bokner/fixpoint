defmodule CPSolver.Variable do
  @callback dom(variable :: any()) :: list()
  @callback propagators(variable :: any()) :: list()
end
