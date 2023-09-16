defmodule CPSolver.Variable do
  defstruct [:id, :name, :domain, :store]

  @type t :: %__MODULE__{
          id: reference(),
          name: String.t(),
          domain: Domain.t()
        }

  alias CPSolver.Variable
  alias CPSolver.Utils
  alias CPSolver.DefaultDomain, as: Domain

  import CPSolver.Propagator.Variable

  require Logger

  @callback new(values :: Enum.t(), opts :: Keyword.t()) :: Variable.t()

  defmacro __using__(_) do
    quote do
      @behaviour CPSolver.Variable

      def new(values, opts \\ default_opts()) do
        %Variable{
          id: make_ref(),
          store: Keyword.get(opts, :store),
          domain: Domain.new(values)
        }
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

  def fixed?(%{domain: domain} = variable) do
    Domain.fixed?(domain) ||
      store_op(:fixed?, variable)
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
    get_store_impl().update(variable.store, variable, op, [value])
  end

  defp store_op(op, variable, value) when op in [:contains?] do
    get_store_impl().get(variable.store, variable, op, [value])
  end

  defp store_op(op, variable) when op in [:size, :fixed?, :min, :max] do
    get_store_impl().get(variable.store, variable, op)
  end

  defp store_op(:domain, variable) do
    get_store_impl().domain(variable.store, variable)
  end

  def subscribers(variable) do
    Utils.subscribers(variable_topic(variable))
  end

  def subscribe(pid, variable) do
    Utils.subscribe(pid, variable_topic(variable))
  end

  def unsubscribe(subscriber, var) do
    Utils.unsubscribe(subscriber, variable_topic(var))
  end

  def publish(variable, message) do
    Utils.publish(variable_topic(variable), message)
  end

  defp variable_topic(var) when is_map(var) do
    variable_topic(var.id)
  end

  defp variable_topic(var) when is_reference(var) do
    {:variable, var}
  end
end
