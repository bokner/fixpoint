defmodule CPSolver.Constraint do
  @callback propagators() :: [function()]

  def new(constraint_impl, args) do
    %{propagators: constraint_impl.propagators(args)}
  end
end
