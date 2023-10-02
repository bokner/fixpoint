defmodule CPSolver.Store.ETS do
  alias CPSolver.DefaultDomain, as: Domain

  use CPSolver.ConstraintStore
  alias CPSolver.ConstraintStore
  @domain_changes CPSolver.Common.domain_changes()

  @impl true
  def create(variables, _opts \\ []) do
    table_id =
      :ets.new(__MODULE__, [:set, :public, read_concurrency: true, write_concurrency: true])

    Enum.each(
      variables,
      fn var ->
        :ets.insert(table_id, {var.id, %{domain: Domain.new(var.domain), subscriptions: []}})
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
            update_variable_domain(store, variable, new_domain)
            domain_change

          :fail ->
            update_variable_domain(store, variable, :fail)
            :fail

          :no_change ->
            :no_change
        end)
    end)
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
    variables = :ets.tab2list(store) |> Map.new()

    subscriptions
    |> Enum.map(&ConstraintStore.normalize_subscription/1)
    |> Enum.group_by(fn s -> s.variable end, fn s -> Map.delete(s, :variable) end)
    |> Map.merge(variables, fn _var, new_subscr, variable ->
      (new_subscr ++ variable.subscriptions)
      |> Enum.uniq_by(fn s -> s.pid end)
      |> then(fn updated_subscriptions ->
        Map.put(variable, :subscriptions, updated_subscriptions)
      end)
    end)
    |> then(fn updated_variables ->
      Enum.each(updated_variables, fn {var_id, var_data} ->
        :ets.insert(store, {var_id, var_data})
      end)
    end)
  end

  defp update_variable_domain(store, variable, domain) do
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
