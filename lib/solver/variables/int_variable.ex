defmodule CPSolver.IntVariable do
  use CPSolver.Variable

  defdelegate new(domain, name \\ nil, space \\ nil), to: CPSolver.Variable
end
