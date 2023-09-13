defmodule CPSolver.Store.ETS do
  alias CPSolver.DefaultDomain, as: Domain

  @behaviour CPSolver.ConstraintStore

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
  def update(store, variable, operation, args) do
    store
    |> domain(variable)
    |> then(fn domain ->
      apply(Domain, operation, [domain | args])
      |> tap(fn
        {_changed, new_domain} ->
          :ets.insert(store, {variable.id, Map.put(variable, :domain, new_domain)})

        _not_changed ->
          :ok
      end)
    end)
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
