defmodule CPSolver.Variable do
  defstruct [:id, :name, :domain, :store]

  @type t :: %__MODULE__{
          id: reference(),
          name: String.t(),
          domain: Domain.t()
        }

  alias CPSolver.Variable
  alias CPSolver.DefaultDomain, as: Domain

  require Logger

  @callback new(values :: Enum.t(), opts :: Keyword.t()) :: Variable.t()

  defmacro __using__(_) do
    quote do
      @behaviour CPSolver.Variable

      def new(values, opts \\ default_opts()) do
        id = make_ref()

        %Variable{
          id: id,
          name: Keyword.get(opts, :name, id),
          store: Keyword.get(opts, :store),
          domain: Domain.new(values)
        }
      end

      def copy(variable) do
        Map.put(variable, :id, make_ref())
      end

      defp default_opts() do
        [domain_impl: CPSolver.DefaultDomain]
      end

      defoverridable new: 2
    end
  end

  def domain(variable) do
    store_op(:domain, variable)
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

  defp store_op(op, %{store: store, store_impl: store_impl} = variable, value)
       when op in [:remove, :removeAbove, :removeBelow, :fix] do
    store_impl.update(store, variable, op, [value])
  end

  defp store_op(op, %{store: store, store_impl: store_impl} = variable, value)
       when op in [:contains?] do
    store_impl.get(store, variable, op, [value])
  end

  defp store_op(op, %{store: store, store_impl: store_impl} = variable)
       when op in [:size, :fixed?, :min, :max] do
    store_impl.get(store, variable, op)
  end

  defp store_op(:domain, %{store: store, store_impl: store_impl} = variable) do
    store_impl.domain(store, variable)
  end
end
