defmodule CPSolver.Store.ETS do
  alias CPSolver.DefaultDomain, as: Domain

  use CPSolver.ConstraintStore

  @impl true
  def create(variables, _opts \\ []) do
    table_id =
      :ets.new(__MODULE__, [:set, :private, read_concurrency: true, write_concurrency: true])

    {:ok,
     Enum.map(
       variables,
       fn var ->
         :ets.insert(table_id, {var.id, var})
         # Bind variable to the store instance
         Map.put(var, :store, table_id)
       end
     ), table_id}
  end

  @impl true
  def dispose(store, variable) do
    :ets.delete(store, variable.id)
    :ok
  end

  @impl true
  def get_variables(store) do
    :ets.tab2list(store)
  end

  @impl true
  def get(store, variable, operation, args \\ []) do
    store
    |> domain(variable)
    |> then(fn domain -> apply(Domain, operation, [domain | args]) end)
  end

  @impl true
  def update_domain(store, variable, operation, args) do
    store
    |> domain(variable)
    |> then(fn domain ->
      apply(Domain, operation, [domain | args])
      |> then(fn
        {domain_change, new_domain} ->
          update_domain(store, variable, new_domain)
          domain_change
        :fail ->
          update_domain(store, variable, :fail)
          :fail
        :no_change
          :no_change
      end)
    end)
  end

  defp update_domain(store, variable, domain) do
    :ets.insert(store, {variable.id, Map.put(variable, :domain, domain)})
  end

  @impl true
  def domain(store, variable) do
    store
    |> lookup(variable)
    |> Map.get(:domain)
  end

  def lookup(store, variable) do
    store
    |> :ets.lookup(variable.id)
    |> hd
    |> elem(1)
  end
end
