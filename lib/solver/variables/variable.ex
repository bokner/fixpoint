defmodule CPSolver.Variable do
  defstruct [:id, :index, :name, :domain, :initial_size, :store, :propagate_on]

  @type t :: %__MODULE__{
          id: reference(),
          index: integer(),
          name: term(),
          domain: Domain.t(),
          initial_size: integer(),
          propagate_on: Propagator.propagator_event()
        }

  alias CPSolver.Variable
  alias CPSolver.Variable.View
  alias CPSolver.DefaultDomain, as: Domain

  require Logger

  @callback new(values :: Enum.t(), opts :: Keyword.t()) :: Variable.t()

  defmacro __using__(_) do
    quote do
      @behaviour CPSolver.Variable

      def new(values, opts \\ []) do
        id = make_ref()

        domain = Domain.new(values)

        %Variable{
          id: id,
          name: Keyword.get(opts, :name, id),
          domain: domain,
          initial_size: Domain.size(domain)
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

  def domain(variable, _shape \\ :handle) do
    apply_op(:domain, variable)
  end

  def size(variable) do
    apply_op(:size, variable)
  end

  def fixed?(variable) do
    apply_op(:fixed?, variable)
  end

  def min(variable) do
    apply_op(:min, variable)
  end

  def max(variable) do
    apply_op(:max, variable)
  end

  def contains?(variable, value) do
    apply_op(:contains?, variable, value)
  end

  def remove(variable, value) do
    apply_op(:remove, variable, value)
  end

  def removeAbove(variable, value) do
    apply_op(:removeAbove, variable, value)
  end

  def removeBelow(variable, value) do
    apply_op(:removeBelow, variable, value)
  end

  def fix(variable, value) do
    apply_op(:fix, variable, value)
  end

  defp apply_op(op, %{domain: domain} = _variable, value)
       when op in [:remove, :removeAbove, :removeBelow, :fix] do
      apply(Domain, op, [domain, value]) |> normalize_update_result()
  end

  defp apply_op(:contains?, %{domain: domain} = _variable, value) do
      Domain.contains?(domain, value)
  end

  defp apply_op(op, %View{variable: variable}) do
    apply_op(op, variable)
  end

  defp apply_op(op, %{domain: domain} = _variable)
       when op in [:size, :fixed?, :min, :max] do
    apply(Domain, op, [domain])
  end

  defp apply_op(:domain, %{domain: domain}) when not is_nil(domain) do
    domain
  end

  defp normalize_update_result({change, _}), do: change

  defp normalize_update_result(change), do: change
end
