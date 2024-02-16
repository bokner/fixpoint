defmodule CPSolver.Constraint do
  alias CPSolver.Variable
  alias CPSolver.Variable.Interface

  @callback new(args :: list()) :: Constraint.t()
  @callback propagators(args :: list()) :: [atom()]
  @callback variables(args :: list()) :: [Variable.t()]

  defmacro __using__(_) do
    quote do
      @behaviour CPSolver.Constraint
      alias CPSolver.Constraint
      alias CPSolver.Common

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
    constraint_mod.propagators(args)
  end

  def constraint_to_propagators(constraint) when is_tuple(constraint) do
    [constraint_mod | args] = Tuple.to_list(constraint)
    constraint_to_propagators({constraint_mod, args})
  end

  def extract_variables({_mod, args}) do
    Enum.flat_map(args, fn arg ->
      var = Interface.variable(arg)
      (var && [var]) || []
    end)
  end
end

defmodule CPSolver.Constraint.Factory do
  import CPSolver.Utils

  alias CPSolver.Constraint.Element2D

  def element2d(array2d, x, y) do
    domain = array2d |> List.flatten()
    z = Variable.new(domain)
    {z, Element2D.new([array2d, x, y, z])}
  end

end

