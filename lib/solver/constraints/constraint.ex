defmodule CPSolver.Constraint do
  alias CPSolver.Variable

  @callback propagators(args :: list()) :: [atom()]
  @callback variables(args :: list()) :: [Variable.t()]

  defmacro __using__(_) do
    quote do
      @behaviour CPSolver.Constraint
      def variables(args) do
        args
      end

      defoverridable variables: 1
    end
  end

  def new(constraint_impl, args) do
    %{
      propagators: Enum.map(constraint_impl.propagators(args), fn p -> p.filter(args) end),
      scope: constraint_impl.variables(args)
    }
  end
end
