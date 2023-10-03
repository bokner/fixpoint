defmodule CPSolver.Store.ETS do
  alias CPSolver.DefaultDomain, as: Domain

  use CPSolver.ConstraintStore
  alias CPSolver.ConstraintStore

  @impl true
  def create(variables, _opts \\ []) do
    table_id =
      :ets.new(__MODULE__, [:set, :public, read_concurrency: true, write_concurrency: true])

    Enum.each(
      variables,
      fn var ->
        :ets.insert(
          table_id,
          {var.id, %{id: var.id, domain: Domain.new(var.domain), subscriptions: []}}
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
  def on_no_change(_store, _variable) do
    :ok
  end

  @impl true
  def on_fail(_store, _variable) do
    :ok
  end

  @impl true
  def subscribe(store, subscriptions) do
    subscriptions_by_var = Enum.group_by(subscriptions, fn s -> s.variable end)

    Enum.each(subscriptions_by_var, fn {var_id, subscrs} ->
      var_rec = lookup(store, var_id)

      updated_rec = %{
        var_rec
        | subscriptions: (var_rec.subscriptions ++ subscrs) |> Enum.uniq_by(fn rec -> rec.pid end)
      }

      true = :ets.insert(store, {var_id, updated_rec})
    end)
  end

  defp update_variable_domain(
         store,
         %{id: var_id, subscriptions: subscriptions} = variable,
         domain,
         event
       ) do
    :ets.insert(store, {variable.id, Map.put(variable, :domain, domain)})
    |> tap(fn _ -> ConstraintStore.notify_subscribers(var_id, event, subscriptions) end)
  end

  @impl true
  def domain(store, variable) do
    store
    |> lookup(variable)
    |> Map.get(:domain)
  end

  def lookup(store, %{id: var_id} = _variable) do
    lookup(store, var_id)
  end

  def lookup(store, var_id) do
    store
    |> :ets.lookup(var_id)
    |> hd
    |> elem(1)
  end

  defp handle_request(kind, store, var_id, operation, args) do
    variable = lookup(store, var_id)
    handle_request_impl(kind, store, variable, operation, args)
  end

  def handle_request_impl(_kind, _store, %{domain: :fail} = _variable, _operation, _args) do
    :fail
  end

  def handle_request_impl(:get, _store, %{domain: domain} = _variable, operation, args) do
    apply(Domain, operation, [domain | args])
  end

  def handle_request_impl(:update, store, %{domain: domain} = variable, operation, args) do
    case apply(Domain, operation, [domain | args]) do
      :fail ->
        :fail
        |> tap(fn _ -> update_variable_domain(store, variable, :fail, :fail) end)

      :no_change ->
        :no_change

      {domain_change, new_domain} ->
        domain_change
        |> tap(fn _ -> update_variable_domain(store, variable, new_domain, domain_change) end)
    end
  end
end
