defmodule CPSolver.Store.ETS do
  alias CPSolver.DefaultDomain, as: Domain

  use CPSolver.ConstraintStore
  alias CPSolver.ConstraintStore

  @impl true
  def create(variables, opts \\ []) do
    table_id =
      :ets.new(__MODULE__, [:set, :public, read_concurrency: true, write_concurrency: true])

    space = Keyword.get(opts, :space)
    constraint_graph = Keyword.get(opts, :constraint_graph)

    store = %{
      space: space,
      handle: table_id,
      store_impl: __MODULE__,
      constraint_graph: constraint_graph
    }

    Enum.each(
      variables,
      fn var ->
        :ets.insert(
          table_id,
          {var.id, %{id: var.id, store: store, domain: Domain.new(var.domain), subscriptions: []}}
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
    handle_request(:update, store, variable, operation, args,
      source: Map.get(variable, :propagator_id)
    )
  end

  @impl true
  def on_change(_store, _variable, _change) do
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

  @impl true
  def subscribe(table, subscriptions) do
    subscriptions_by_var =
      subscriptions
      |> Enum.map(&ConstraintStore.normalize_subscription/1)
      |> Enum.group_by(fn s -> s.variable end)

    Enum.each(subscriptions_by_var, fn {var_id, subscrs} ->
      var_rec = lookup(table, var_id)

      updated_rec = %{
        var_rec
        | subscriptions: (var_rec.subscriptions ++ subscrs) |> Enum.uniq_by(fn rec -> rec.pid end)
      }

      true = :ets.insert(table, {var_id, updated_rec})
    end)
  end

  defp update_variable_domain(
         table,
         %{id: var_id} = variable,
         domain,
         event,
         opts \\ []
       ) do
    :ets.insert(table, {var_id, Map.put(variable, :domain, domain)})
    |> tap(fn _ -> ConstraintStore.notify(variable, event, opts) end)
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

  defp handle_request(kind, table, var_id, operation, args, opts \\ [])

  defp handle_request(kind, table, var_id, operation, args, opts) do
    variable = lookup(table, var_id)
    handle_request_impl(kind, table, variable, operation, args, opts)
  end

  def handle_request_impl(_kind, _table, %{domain: :fail} = _variable, _operation, _args, _opts) do
    :fail
  end

  def handle_request_impl(:get, _table, %{domain: domain} = _variable, operation, args, _opts) do
    apply(Domain, operation, [domain | args])
  end

  def handle_request_impl(:update, table, %{domain: domain} = variable, operation, args, opts) do
    case apply(Domain, operation, [domain | args]) do
      :fail ->
        update_variable_domain(table, variable, :fail, :fail, opts)
        :fail

      :no_change ->
        :no_change

      {domain_change, new_domain} ->
        update_variable_domain(table, variable, new_domain, domain_change, opts)
        domain_change
    end
  end
end
