defmodule CPSolver.Variable do
  defstruct [:id, :name, :domain, :space]

  @type t :: %__MODULE__{
          id: reference(),
          name: String.t(),
          domain: Domain.t()
        }

  alias CPSolver.Variable
  alias CPSolver.Store.Registry, as: Store
  alias CPSolver.Utils
  alias CPSolver.DefaultDomain, as: Domain

  require Logger

  @callback new(values :: Enum.t(), opts :: Keyword.t()) :: Variable.t()

  defmacro __using__(_) do
    quote do
      @behaviour CPSolver.Variable

      def new(values, opts \\ default_opts()) do
        %Variable{
          id: make_ref(),
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
    Store.update(variable.space, variable, op, [value])
  end

  defp store_op(op, variable, value) when op in [:contains?] do
    Store.get(variable.space, variable, op, [value])
  end

  defp store_op(op, variable) when op in [:size, :fixed?, :min, :max] do
    Store.get(variable.space, variable, op)
  end

  defp store_op(:domain, variable) do
    Store.domain(variable.space, variable)
  end

  def subscribers(variable) do
    Utils.subscribers(variable_topic(variable))
  end

  def subscribe(pid, variable) do
    Utils.subscribe(pid, variable_topic(variable))
  end

  def unsubscribe(subscriber, var) do
    Utils.unsubscribe(subscriber, var)
  end

  def publish(variable, message) do
    Utils.publish(variable_topic(variable), message)
  end

  defp variable_topic(var) do
    {:variable, var.id}
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

defmodule CPSolver.Variable.Agent do
  alias CPSolver.DefaultDomain, as: Domain
  alias CPSolver.Store.Registry, as: StoreRegistry
  alias CPSolver.Variable
  alias CPSolver.Utils

  require Logger

  @behaviour GenServer
  def create(space, %{id: id} = variable) do
    {:ok, _} = Registry.register(StoreRegistry, id, space)

    {:ok, _pid} =
      GenServer.start_link(__MODULE__, variable, name: StoreRegistry.variable_proc_id(variable))
  end

  def dispose(variable) do
    topic = {variable, variable.id}
    Enum.each(Utils.subscribers(topic), fn s -> Utils.unsubscribe(s, topic) end)
    GenServer.stop(StoreRegistry.variable_proc_id(variable))
  end

  @impl true
  @spec init(atom | %{:domain => any, optional(any) => any}) :: {:ok, :gb_sets.set(any)}
  def init(variable) do
    {:ok, Domain.new(variable.domain)}
  end

  def operation(var, operation, args \\ []) do
    GenServer.call(StoreRegistry.variable_proc_id(var), {var, operation, args})
  end

  @impl true
  def handle_call({var, op, _args}, _from, :fail) do
    handle_op_on_failed_var(var, op)
    {:reply, :fail, :fail}
  end

  ## Read ops
  def handle_call({_var, :domain, _args}, _from, domain) do
    {:reply, domain, domain}
  end

  def handle_call({_var, op, args}, _from, domain)
      when op in [:size, :fixed?, :min, :max, :contains?] do
    {:reply, apply(Domain, op, [domain | args]), domain}
  end

  ## Write ops
  def handle_call({var, op, args}, _from, domain)
      when op in [:remove, :removeAbove, :removeBelow, :fix] do
    {result, updated_domain} =
      case apply(Domain, op, [domain | args]) do
        :fail ->
          {:fail, :fail}
          |> tap(fn _ -> handle_failure(var) end)

        :none ->
          {:no_change, domain}
          |> tap(fn _ -> handle_domain_no_change(var) end)

        {domain_change, new_domain} ->
          {domain_change, new_domain}
          |> tap(fn _ -> handle_domain_change(domain_change, var, new_domain) end)
      end

    {:reply, result, updated_domain}
  end

  defp handle_op_on_failed_var(var, operation) do
    Logger.warning(
      "Attempt to request #{inspect(operation)} on failed variable #{inspect(var.id)}"
    )
  end

  defp handle_failure(var) do
    Logger.debug("Failure for variable #{inspect(var.id)}")
    ## TODO: notify space (and maybe don't notify propagators)
    publish(var, {:fail, var.id})
  end

  defp handle_domain_no_change(_var) do
    :ok
  end

  defp handle_domain_change(domain_change, var, _domain) do
    publish(var, {domain_change, var.id})
    |> tap(fn _ ->
      Logger.debug("Domain change (#{domain_change}) for #{inspect(var.id)}")
      maybe_unsubscribe_all(domain_change, var)
    end)
  end

  defp publish(var, message) do
    Variable.publish(var, message)
  end

  defp maybe_unsubscribe_all(:fixed, var) do
    Enum.each(Variable.subscribers(var), fn pid -> Variable.unsubscribe(pid, var) end)
  end

  defp maybe_unsubscribe_all(_, _var) do
    :ok
  end
end
