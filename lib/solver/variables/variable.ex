defmodule CPSolver.Variable do
  defstruct [:id, :name, :space, :backend, :domain, :domain_impl]

  @type t :: %__MODULE__{
          id: reference(),
          name: String.t(),
          space: any(),
          backend: atom(),
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

  defp backend_op(
         op,
         %Variable{id: var_id, backend: backend, space: space, domain_impl: domain_impl} =
           variable,
         value
       )
       when op in [:contains?, :remove, :removeAbove, :removeBelow, :fix] do
    case backend.lookup(space, var_id) do
      :not_found ->
        throw({:variable_not_found, variable})

      domain ->
        domain_op_result = apply(domain_impl, op, [domain, value])
        handle_domain_result(op, domain_op_result)
    end
  end

  defp handle_domain_result(read_op, result)
       when read_op in [:size, :fixed?, :min, :max, :contains?] do
    result
  end

  defp handle_domain_result(write_op, result)
       when write_op in [:remove, :removeAbove, :removeBelow, :fix] do
    result
    |> tap(fn
      {_write_op, :fail} ->
        :fail

      {_write_op, :none} ->
        :stable

      {write_op, result} ->
        update_store(write_op, result)
    end)
  end

  defp update_store(write_op, domain_change) do
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
