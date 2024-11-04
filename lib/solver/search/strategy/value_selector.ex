defmodule CPSolver.Search.ValueSelector do
  @callback select_value(Variable.t()) :: integer()
end
