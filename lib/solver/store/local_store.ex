defmodule CPSolver.Store.Local do
  alias CPSolver.ConstraintStore
  alias CPSolver.DefaultDomain, as: Domain

  use ConstraintStore

  use GenServer

  ## Store callbacks
  @impl true
  def create(variables, opts \\ []) do
    variable_map =
      Map.new(
        variables,
        fn var ->
          {var.id, %{domain: Domain.new(var.domain), subscriptions: []}}
        end
      )

    {:ok, _store} = GenServer.start_link(__MODULE__, [variable_map, opts])
  end

  @impl true
  def dispose(store, _variables) do
    GenServer.cast(store, :stop)
  end

  @impl true
  def domain(store, var) do
    GenServer.call(store, {:domain, var.id})
  end

  @impl true
  def get(store, var, operation, args \\ []) do
    GenServer.call(store, {:get, var.id, operation, args})
  end

  @impl true
  def update_domain(store, var, operation, args \\ []) do
    GenServer.call(store, {:update, var.id, operation, args})
  end

  @impl true
  def on_change(_store, _variable, _change) do
    :ok
  end

  @impl true
  def on_fail(_store, _variable) do
    :ok
  end

  @impl true
  def on_no_change(_store, _variable) do
    :ok
  end

  @impl true
  def get_variables(store) do
    GenServer.call(store, :get_variables)
  end

  @impl true
  def subscribe(store, subscriptions) do
    GenServer.cast(
      store,
      {:subscribe, Enum.map(subscriptions, &ConstraintStore.normalize_subscription/1)}
    )
  end

  ## GenServer callbacks
  @impl true
  def init([variables, _opts]) do
    {:ok, %{variables: variables}}
  end

  @impl true
  def handle_call({:domain, var}, _from, data) do
    {:reply, get_domain(var, data), data}
  end

  def handle_call({request_kind, var, operation, args}, _from, data)
      when request_kind in [:update, :get] do
    var
    |> get_domain(data)
    |> handle_request(request_kind, var, operation, args, data)
  end

  def handle_call(:get_variables, _from, %{variables: variables} = data) do
    var_ids = Map.keys(variables)
    {:reply, var_ids, data}
  end

  @impl true
  def handle_cast({:subscribe, subscriptions}, %{variables: variables} = data) do
    new_data =
      subscriptions
      |> Enum.group_by(fn s -> s.variable end, fn s -> Map.delete(s, :variable) end)
      |> Map.merge(variables, fn _var, new_subscr, variable ->
        (new_subscr ++ variable.subscriptions)
        |> Enum.uniq_by(fn s -> s.pid end)
        |> then(fn updated_subscriptions ->
          Map.put(variable, :subscriptions, updated_subscriptions)
        end)
      end)
      |> then(fn updated_variables -> Map.put(data, :variables, Map.new(updated_variables)) end)

    {:noreply, new_data}
  end

  def handle_cast(:stop, data) do
    {:stop, :normal, data}
  end

  defp handle_request(nil, _, _, _, _, data) do
    {:reply, :not_found, data}
  end

  defp handle_request(:fail, _, _, _, _, data) do
    {:reply, :fail, data}
  end

  defp handle_request(domain, :get, _variable, operation, args, data) do
    {:reply, apply(Domain, operation, [domain | args]), data}
  end

  defp handle_request(domain, :update, variable, operation, args, data) do
    {result, new_data} =
      case apply(Domain, operation, [domain | args]) do
        :fail ->
          {:fail, update_variable_domain(variable, :fail, :fail, data)}

        :no_change ->
          {:no_change, data}

        {domain_change, new_domain} ->
          {domain_change, update_variable_domain(variable, new_domain, domain_change, data)}
      end

    {:reply, result, new_data}
  end

  defp get_domain(var_id, %{variables: variables} = _data) do
    case Map.get(variables, var_id) do
      nil -> nil
      %{domain: domain} -> domain
    end
  end

  defp update_variable_domain(var_id, domain, event, %{variables: variables} = data) do
    variables
    |> Map.get(var_id)
    |> Map.put(:domain, domain)
    |> then(fn updated_var ->
      updated_vars = Map.put(variables, var_id, updated_var)
      Map.put(data, :variables, updated_vars)
    end)
    |> tap(fn updated_data -> notify_subscribers(var_id, event, updated_data) end)
  end

  defp notify_subscribers(_var, :no_change, _) do
    :ignore
  end

  defp notify_subscribers(var, event, %{variables: variables} = _data) do
    subscriptions = Map.get(variables, var) |> Map.get(:subscriptions)
    Enum.each(subscriptions, fn s -> ConstraintStore.notify_subscriber(s, var, event) end)
  end

end
