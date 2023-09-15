defmodule CPSolver.IntVariable do
  use CPSolver.Variable

  alias CPSolver.Variable

  defdelegate domain(var), to: Variable
  defdelegate size(var), to: Variable
  defdelegate min(var), to: Variable
  defdelegate max(var), to: Variable
  defdelegate fixed?(var), to: Variable
  defdelegate contains?(var, val), to: Variable
  defdelegate remove(var, val), to: Variable
  defdelegate removeAbove(var, val), to: Variable
  defdelegate removeBelow(var, val), to: Variable
  defdelegate fix(var, val), to: Variable
end
