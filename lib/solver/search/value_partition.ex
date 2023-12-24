defmodule CPSolver.Search.ValuePartition do
  alias CPSolver.Variable
  @callback partition(Variable.t()) :: {:ok, [Domain.t() | number()]} | {:error, any()}
end
