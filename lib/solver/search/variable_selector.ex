defmodule CPSolver.Search.VariableSelector do
  @callback select_variable([Variable.t()]) :: Variable.t() | nil
end
