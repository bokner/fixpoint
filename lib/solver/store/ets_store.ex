defmodule CPSolver.Store.ETS do
  alias CPSolver.DefaultDomain, as: Domain

  use CPSolver.ConstraintStore

  @impl true
  def create(variables, opts \\ []) do
    table_id =
      :ets.new(__MODULE__, [:set, :public, read_concurrency: true, write_concurrency: false])

    space = Keyword.get(opts, :space)

    store = %{
      space: space,
      handle: table_id,
      store_impl: __MODULE__
    }

    Enum.each(
      variables,
      fn var ->
        :ets.insert(
          table_id,
          {var.id, %{id: var.id, store: store, domain: Domain.new(var.domain)}}
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
  def get_variables(store) do
    :ets.tab2list(store) |> Enum.map(fn {_id, var} -> var.id end)
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
         table,
         variable,
         _domain,
         :fail
       ) do
    :fail
  end

  defp update_variable_domain(
         table,
         domain,
         event
       ) do
    case event do
      :fixed -> {:fixed, Domain.min(domain)}
      event -> event
    end
  end

  @impl true
  def domain(table, variable) do
    Map.get(variable, :domain)
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

  defp handle_request(kind, table, variable, operation, args) do
    variable = lookup(table, variable)
    handle_request_impl(kind, table, variable.domain, operation, args)
  end

  def handle_request_impl(:get, _table, domain, operation, args) do
    safe_apply(operation, domain, args)
  end

  def handle_request_impl(:update, table, domain, operation, args) do
    case safe_apply(operation, domain, args) do
      :fail ->
        update_variable_domain(table, :fail, :fail)

      :no_change ->
        :no_change

      {domain_change, new_domain} ->
        update_variable_domain(table, new_domain, domain_change)
    end
  end

  defp safe_apply(operation, domain, args) do
    (Domain.fail?(domain) && :fail) ||
      apply(Domain, operation, [domain | args])
  end
end
