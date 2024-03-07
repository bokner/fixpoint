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
  alias CPSolver.Constraint.{Sum, Element, Element2D}
  alias CPSolver.IntVariable, as: Variable
  alias CPSolver.Variable.Interface
  alias CPSolver.DefaultDomain, as: Domain

  def element(array, x, opts \\ []) do
    domain = array
    y = Variable.new(domain, name: Keyword.get(opts, :name, make_ref()))
    {y, Element.new(array, x, y)}
  end

  def element2d(array2d, x, y, opts \\ []) do
    domain = array2d |> List.flatten()
    z = Variable.new(domain, name: Keyword.get(opts, :name, make_ref()))
    {z, Element2D.new([array2d, x, y, z])}
  end

  def sum(vars, opts \\ []) do
    {domain_min, domain_max} =
      Enum.reduce(vars, {0, 0}, fn var, {min_acc, max_acc} ->
        domain = Interface.domain(var) |> Domain.to_list()
        {min_acc + Enum.min(domain), max_acc + Enum.max(domain)}
      end)

    sum_var = Variable.new(domain_min..domain_max, name: Keyword.get(opts, :name, make_ref()))
    {sum_var, Sum.new(sum_var, vars)}
  end
end
