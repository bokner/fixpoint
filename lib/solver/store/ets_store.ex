defmodule CPSolver.Store.ETS do
  alias CPSolver.DefaultDomain, as: Domain

  use CPSolver.ConstraintStore

  @impl true
  def create(variables, _opts \\ []) do
    table_id =
      :ets.new(__MODULE__, [:set, :public, read_concurrency: true, write_concurrency: false])

    Enum.each(
      variables,
      fn var ->
        :ets.insert(
          table_id,
          {var.id, %{id: var.id, domain: var.domain}}
        )
      end
    )

    {:ok, table_id}
  end

  @impl true
  def dispose(_store, _vars) do
    :ok
  end

  @impl true
  def get(store, variable, operation, args \\ []) do
    handle_request(:get, store, variable, operation, args)
  end

  @impl true
  def update_domain(store, variable, operation, args) do
    handle_request(:update, store, variable, operation, args)
  end

  @impl true
  def on_change(_store, _variable, _change) do
    :ok
  end

  @impl true
  def on_fix(_store, _variable, _value) do
    :ok
  end

  @impl true
  def on_no_change(_store, _variable) do
    :ok
  end

  @impl true
  def on_fail(_store, _variable) do
    :ok
  end

  defp update_variable_domain(
         _table,
         _variable,
         _domain,
         event
       ) do
    event
  end

  @impl true
  def domain(table, variable) do
    table
    |> lookup(variable)
    |> Map.get(:domain)
  end

  def lookup(table, %{id: var_id} = _variable) do
    lookup(table, var_id)
  end

  def lookup(table, var_id) do
    table
    |> :ets.lookup(var_id)
    |> hd
    |> elem(1)
  end

  defp handle_request(kind, table, var_id, operation, args) do
    variable = lookup(table, var_id)
    handle_request_impl(kind, table, variable, operation, args)
  end

  def handle_request_impl(:get, _table, %{domain: domain} = _variable, operation, args) do
    apply(Domain, operation, [domain | args])
  end

  def handle_request_impl(:update, table, %{domain: domain} = variable, operation, args) do
    case apply(Domain, operation, [domain | args]) do
      :fail ->
        update_variable_domain(table, variable, :fail, :fail)

      :no_change ->
        :no_change

      :fixed ->
        update_variable_domain(table, variable, domain, :fixed)

      {domain_change, new_domain} ->
        update_variable_domain(table, variable, new_domain, domain_change)
    end
  end
end
