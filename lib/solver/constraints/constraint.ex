defmodule CPSolver.Constraint do
  alias CPSolver.Propagator

  @callback new(args :: list()) :: Constraint.t()
  @callback propagators(args :: list()) :: [Propagator.t()]
  defmacro __using__(_) do
    quote do
      @behaviour CPSolver.Constraint
      alias CPSolver.Constraint

      def new(args) do
        Constraint.new(__MODULE__, args)
      end
    end

    # defoverridable new: 1
  end

  def new(constraint_mod, args) do
    {constraint_mod, constraint_mod.propagators(args)}
  end

  def constraint_to_propagators({constraint_mod, args}) when is_list(args) do
    args
    |> constraint_mod.propagators()
  end

  def constraint_to_propagators(constraint) when is_tuple(constraint) do
    [constraint_mod | args] = Tuple.to_list(constraint)
    constraint_to_propagators({constraint_mod, args})
  end
end
