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
    (Enum.empty?(args) && throw({constraint_impl, :no_args})) ||
      {constraint_impl, args}
  end

  def constraint_to_propagators(constraint, reducer_fun \\ &Function.identity/1)

  def constraint_to_propagators({constraint_mod, args}, reducer_fun) when is_list(args) do
    List.foldr(constraint_mod.propagators(args), [], fn p, plist_acc ->
      [reducer_fun.(p) | plist_acc]
    end)
  end

  def constraint_to_propagators(constraint, reducer_fun) when is_tuple(constraint) do
    [constraint_mod | args] = Tuple.to_list(constraint)
    constraint_to_propagators({constraint_mod, args}, reducer_fun)
  end

  def post(constraint) when is_tuple(constraint) do
    constraint_to_propagators(constraint,
    fn p ->
      case Propagator.filter(p) do
           :fail -> throw({:fail, p.id})
           %{state: state} -> Propagator.update_state(p, state)
           _ -> p
      end
    end)
  end

  def extract_variables(constraint) do
    constraint
    |> constraint_to_propagators()
    |> Enum.map(fn p ->
      p
      |> Propagator.variables()
      |> Enum.map(fn var -> Interface.variable(var) end)
    end)
    |> List.flatten()
    |> Enum.uniq()
  end
end
