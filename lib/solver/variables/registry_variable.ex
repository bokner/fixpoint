defmodule CPSolver.Variable.Agent do
  alias CPSolver.DefaultDomain, as: Domain
  alias CPSolver.Store.Registry, as: StoreRegistry
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
  def handle_call({_var, _op, _args}, _from, :fail) do
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
  def handle_call({_var, op, args}, _from, domain)
      when op in [:remove, :removeAbove, :removeBelow, :fix] do
    {result, updated_domain} =
      case apply(Domain, op, [domain | args]) do
        :fail ->
          {:fail, :fail}

        :no_change ->
          {:no_change, domain}

        {domain_change, new_domain} ->
          {domain_change, new_domain}
      end

    {:reply, result, updated_domain}
  end

  @impl true
  def handle_cast(:dispose, state) do
    {:stop, :normal, state}
  end
end
