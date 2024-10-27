defmodule CPSolver.Search.VariableSelector do
  @callback select_variable([Variable.t()]) :: Variable.t() | nil
  @callback select_variable([Variable.t()], any()) :: Variable.t() | nil
  @optional_callbacks select_variable: 1, select_variable: 2
end
