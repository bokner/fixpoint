defmodule CPSolver.Variable.Agent do
  alias CPSolver.DefaultDomain, as: Domain
  alias CPSolver.Store.Registry, as: StoreRegistry
  alias CPSolver.Variable
  alias CPSolver.Utils

  require Logger

  @behaviour GenServer
  def create(%{id: id} = variable) do
    {:ok, _} = Registry.register(StoreRegistry, id, self())

    {:ok, _pid} =
      GenServer.start_link(__MODULE__, variable, name: StoreRegistry.variable_proc_id(variable))
  end

  def dispose(variable) do
    topic = {variable, variable.id}
    Enum.each(Utils.subscribers(topic), fn s -> Utils.unsubscribe(s, topic) end)
    GenServer.cast(StoreRegistry.variable_proc_id(variable), :dispose)
  end

  def alive?(variable) do
    case GenServer.whereis(StoreRegistry.variable_proc_id(variable)) do
      nil -> false
      pid -> Process.alive?(pid)
    end
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

  @impl true
  def handle_cast(:dispose, state) do
    {:stop, :normal, state}
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
