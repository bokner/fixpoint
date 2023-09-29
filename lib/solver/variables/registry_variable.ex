defmodule CPSolver.Variable.Agent do
  alias CPSolver.DefaultDomain, as: Domain
  alias CPSolver.Store.Registry, as: StoreRegistry

  require Logger

  @behaviour GenServer
  def create(%{id: id} = variable, opts \\ []) do
    registry? = Keyword.get(opts, :registry, true)

    if registry? do
      {:ok, _} = Registry.register(StoreRegistry, id, self())

      {:ok, _pid} =
        GenServer.start_link(__MODULE__, variable, name: StoreRegistry.variable_proc_id(variable))
    else
      {:ok, _pid} = GenServer.start_link(__MODULE__, variable)
    end
  end

  def dispose(variable) do
    case GenServer.whereis(StoreRegistry.variable_proc_id(variable)) do
      nil -> false
      pid when is_pid(pid) -> Process.exit(pid, :brutal_kill)
    end
  end

  @impl true
  @spec init(atom | %{:domain => any, optional(any) => any}) :: {:ok, :gb_sets.set(any)}
  def init(variable) do
    {:ok, Domain.new(variable.domain)}
  end

  def operation(var, operation, args \\ [])

  def operation(var, operation, args) when is_pid(var) do
    do_operation(var, operation, args)
  end

  def operation(var, operation, args) do
    handle = StoreRegistry.variable_proc_id(var)
    do_operation(handle, operation, args)
  end

  defp do_operation(variable_handle, operation, args) do
    GenServer.call(variable_handle, {operation, args})
  end

  @impl true
  def handle_call({_op, _args}, _from, :fail) do
    {:reply, :fail, :fail}
  end

  ## Read ops
  def handle_call({:domain, _args}, _from, domain) do
    {:reply, domain, domain}
  end

  def handle_call({op, args}, _from, domain)
      when op in [:size, :fixed?, :min, :max, :contains?] do
    {:reply, apply(Domain, op, [domain | args]), domain}
  end

  ## Write ops
  def handle_call({op, args}, _from, domain)
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
