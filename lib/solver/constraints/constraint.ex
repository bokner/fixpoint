defmodule CPSolver.Constraint do
  alias CPSolver.Variable
  alias CPSolver.Propagator

  @callback new(args :: list()) :: Constraint.t()
  @callback propagators(args :: list()) :: [atom()]
  @callback variables(args :: list()) :: [Variable.t()]

  defmacro __using__(_) do
    quote do
      @behaviour CPSolver.Constraint
      alias CPSolver.Constraint

      def new(args) do
        Constraint.new(__MODULE__, args)
      end

      def variables(args) do
        args
      end

      defoverridable variables: 1
    end
  end

  def new(constraint_impl, args) do
    {constraint_impl, args}
  end

  def constraint_to_propagators({constraint_mod, args}) when is_list(args) do
    args
    |> constraint_mod.propagators()
    |> Enum.map(&Propagator.normalize/1)
  end

  def constraint_to_propagators(constraint) when is_tuple(constraint) do
    [constraint_mod | args] = Tuple.to_list(constraint)
    constraint_to_propagators({constraint_mod, args})
  end
end
