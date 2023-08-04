defmodule CPSolver.Variable do
  defstruct [:id, :name, :space, :backend, :domain]

  @type t :: %__MODULE__{
          id: reference(),
          name: String.t(),
          space: any(),
          backend: atom(),
          domain: any()
        }

  @callback domain(values :: Enum.t()) :: any()
  @callback contains?(variable :: Variable.t(), value :: number()) :: boolean()
  @callback size(variable :: Variable.t()) :: integer()
  @callback min(variable :: Variable.t()) :: number()
  @callback max(variable :: Variable.t()) :: number()
  @callback remove(variable :: Variable.t(), value :: number()) :: any()
  @callback removeAbove(variable :: Variable.t(), value :: number()) :: any()
  @callback removeBelow(variable :: Variable.t(), value :: number()) :: any()
  @callback fix(variable :: Variable.t(), value :: number()) :: any()
  @callback fixed?(variable :: Variable.t()) :: boolean()

  defmacro __using__(_) do
    quote do
      @behaviour CPSolver.Variable
      alias CPSolver.Variable

      def new(values, name \\ nil, space \\ nil) do
        %Variable{id: make_ref(), domain: domain(values), name: name, space: space}
      end

      def domain(values) do
        Enum.reduce(values, :gb_sets.new(), fn v, acc -> :gb_sets.add_element(v, acc) end)
      end

      def size(%Variable{domain: domain}) do
        :gb_sets.size(domain)
      end

      def fixed?(variable) do
        size(variable) == 1
      end

      def min(%Variable{domain: domain}) do
        :gb_sets.smallest(domain)
      end

      def max(%Variable{domain: domain}) do
        :gb_sets.largest(domain)
      end

      def contains?(%Variable{domain: domain}, value) do
        :gb_sets.is_member(value, domain)
      end

      def remove(variable, value) do
        backend_op(:remove, variable, value)
      end

      def removeAbove(variable, value) do
        backend_op(:removeAbove, variable, value)
      end

      def removeBelow(variable, value) do
        backend_op(:removeBelow, variable, value)
      end

      def fix(variable, value) do
        backend_op(:fix, variable, value)
      end

      defp backend_op(op, variable) do
        apply(variable.backend, op, [variable.space, variable.id])
      end

      defp backend_op(op, variable, value)
           when op in [:contains?, :remove, :removeAbove, :removeBelow, :fix] do
        apply(variable.backend, op, [variable.space, variable.id, value])
      end

      defoverridable domain: 1
      defoverridable size: 1
      defoverridable fixed?: 1
      defoverridable min: 1
      defoverridable max: 1
      defoverridable contains?: 2
      defoverridable remove: 2
      defoverridable removeAbove: 2
      defoverridable removeBelow: 2
      defoverridable fix: 2
    end
  end

  def topic(variable) do
    [variable.space, variable.id]
  end

  def bind_variables(space, variables) do
    Enum.map(variables, fn var -> bind(var, space) end)
  end

  def bind(variable, space) do
    Map.put(variable, :space, space)
  end

  def set_backend(variable, backend) do
    Map.put(variable, :backend, backend)
  end
end
