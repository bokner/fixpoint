defmodule CPSolver.Constraint do
  @callback propagators(args :: list()) :: [function()]

  def new(constraint_impl, args) do
    %{propagators: constraint_impl.propagators(args)}
  end
end
