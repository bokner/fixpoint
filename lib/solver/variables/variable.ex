defmodule CPSolver.Variable do
  defstruct [:id, :name, :space, :store, :domain, :domain_impl]

  @type t :: %__MODULE__{
          id: reference(),
          name: String.t(),
          space: any(),
          store: atom(),
          domain: any(),
          domain_impl: module()
        }

  alias CPSolver.Variable

  @callback new(values :: Enum.t(), opts :: Keyword.t()) :: Variable.t()

  defmacro __using__(_) do
    quote do
      @behaviour CPSolver.Variable

      def new(values, opts \\ default_opts()) do
        domain_impl = Keyword.get(opts, :domain_impl)

        %Variable{
          id: make_ref(),
          domain: domain_impl.new(values),
          domain_impl: domain_impl,
          name: Keyword.get(opts, :name),
          space: Keyword.get(opts, :space)
        }
      end

      defp default_opts() do
        [domain_impl: CPSolver.DefaultDomain]
      end

      defoverridable new: 2
    end
  end

  def size(variable) do
    store_op(:size, variable)
  end

  def fixed?(variable) do
    store_op(:fixed?, variable)
  end

  def min(variable) do
    store_op(:min, variable)
  end

  def max(variable) do
    store_op(:max, variable)
  end

  def contains?(variable, value) do
    store_op(:contains?, variable, value)
  end

  def remove(variable, value) do
    store_op(:remove, variable, value)
  end

  def removeAbove(variable, value) do
    store_op(:removeAbove, variable, value)
  end

  def removeBelow(variable, value) do
    store_op(:removeBelow, variable, value)
  end

  def fix(variable, value) do
    store_op(:fix, variable, value)
  end

  defp store_op(op, variable, value) when op in [:remove, :removeAbove, :removeBelow, :fix] do
    apply(variable.store, :update_domain, [variable.id, {op, value}])
  end

  defp store_op(op, variable, value) when op in [:contains?] do
    apply(variable.store, :get, [variable.id, {op, value}])
  end

  defp store_op(op, variable) when op in [:size, :fixed?, :min, :max] do
    apply(variable.store, :get, [variable.id, op])
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

  def set_store(variable, store) do
    Map.put(variable, :store, store)
  end
end
