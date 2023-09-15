defmodule CPSolver.Store.ETS do
  alias CPSolver.DefaultDomain, as: Domain

  use CPSolver.ConstraintStore
  @domain_changes CPSolver.Common.domain_changes()

  @impl true
  def create(variables, _opts \\ []) do
    table_id =
      :ets.new(__MODULE__, [:set, :private, read_concurrency: true, write_concurrency: true])

    {:ok,
     Enum.map(
       variables,
       fn var ->
         # Bind variable to the store instance
         Map.put(var, :store, table_id)
         |> tap(fn var ->
           :ets.insert(table_id, {var.id, var})
         end)
         |> Map.take([:id, :store])
       end
     ), table_id}
  end

  @impl true
  def dispose(store, _vars) do
    :ets.delete(store)
  end

  @impl true
  def get_variables(store) do
    :ets.tab2list(store) |> Enum.map(fn {_id, var} -> var.id end)
  end

  @impl true
  def get(store, variable, operation, args \\ []) do
    store
    |> domain(variable)
    |> then(fn
      :fail -> :fail
      domain -> apply(Domain, operation, [domain | args])
    end)
  end

  @impl true
  def update_domain(store, variable, operation, args) do
    store
    |> domain(variable)
    |> then(fn
      :fail ->
        :fail

      d ->
        apply(Domain, operation, [d | args])
        |> then(fn
          {domain_change, new_domain} when domain_change in @domain_changes ->
            update_variable(store, variable, new_domain)
            domain_change

          :fail ->
            update_variable(store, variable, :fail)
            :fail

          :no_change ->
            :no_change
        end)
    end)
  end

  defp update_variable(store, variable, domain) do
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
