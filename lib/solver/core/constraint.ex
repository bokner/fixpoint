defmodule CPSolver.Constraint do
  alias CPSolver.Variable.Interface
  alias CPSolver.Propagator

  @callback new(args :: list()) :: Constraint.t()
  @callback propagators(args :: list()) :: [atom()]
  @callback arguments(args :: list()) :: list()

  defmacro __using__(_) do
    quote do
      @behaviour CPSolver.Constraint
      alias CPSolver.Constraint
      alias CPSolver.Common

      def new(args) do
        Constraint.new(__MODULE__, arguments(args))
      end

      def arguments(args) do
        args
      end

      defoverridable new: 1, arguments: 1
    end
  end

  def new(constraint_impl, args) do
    {constraint_impl, args}
  end

  def constraint_to_propagators({constraint_mod, args}) when is_list(args) do
    constraint_mod.propagators(args)
  end

  def constraint_to_propagators(constraint) when is_tuple(constraint) do
    [constraint_mod | args] = Tuple.to_list(constraint)
    constraint_to_propagators({constraint_mod, args})
  end

  def post(constraint) when is_tuple(constraint) do
    propagators = constraint_to_propagators(constraint)
    Enum.map(propagators, fn p -> Propagator.filter(p) end)
  end

  def extract_variables({_mod, args}) do
    Enum.flat_map(args, fn arg ->
      var = Interface.variable(arg)
      (var && [var]) || []
    end)
  end
end
