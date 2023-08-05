defmodule CPSolver.Variable do
  defstruct [:id, :name, :space, :backend, :domain]

  @type t :: %__MODULE__{
          id: reference(),
          name: String.t(),
          space: any(),
          backend: atom(),
          domain: any()
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
    backend_op(:size, variable)
  end

  def fixed?(variable) do
    backend_op(:fixed?, variable)
  end

  def min(variable) do
    backend_op(:min, variable)
  end

  def max(variable) do
    backend_op(:max, variable)
  end

  def contains?(variable, value) do
    backend_op(:contains?, variable, value)
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
