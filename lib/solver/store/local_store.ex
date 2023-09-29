defmodule CPSolver.Store.Local do
  alias CPSolver.ConstraintStore
  alias CPSolver.Variable.Agent, as: VariableAgent

  use ConstraintStore

  use GenServer

  ## Store callbacks
  @impl true
  def create(variables, opts \\ []) do
    variable_agents =
      Map.new(
        variables,
        fn var ->
          {:ok, pid} = VariableAgent.create(var, registry: false)
          {var.id, %{agent: pid, subscriptions: []}}
        end
      )

    {:ok, _store} = GenServer.start_link(__MODULE__, [variable_agents, opts])
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
  def on_change(store, variable, change) do
    GenServer.cast(store, {:on_change, variable, change})
  end

  @impl true
  def on_fail(store, variable) do
    GenServer.cast(store, {:on_fail, variable})
  end

  @impl true
  def on_no_change(store, variable) do
    GenServer.cast(store, {:on_no_change, variable})
  end

  @impl true
  def get_variables(store) do
    GenServer.call(store, :get_variables)
  end

  @impl true
  def subscribe(store, subscriptions) do
    GenServer.cast(store, {:subscribe, subscriptions})
  end

  ## GenServer callbacks
  @impl true
  def init([variable_agents, _opts]) do
    {:ok, %{agents: variable_agents}}
  end

  @impl true
  def handle_call({:domain, var}, _from, data) do
    {:reply,
     var
     |> get_agent_pid(data)
     |> VariableAgent.operation(:domain), data}
  end

  def handle_call({request_kind, var, operation, args}, _from, data)
      when request_kind in [:update, :get] do
    ## Locate pid
    reply =
      var
      |> get_agent_pid(data)
      |> then(fn
        nil ->
          {:not_found, var}

        agent_pid ->
          VariableAgent.operation(agent_pid, operation, args)
          |> tap(fn result ->
            request_kind == :update && notify_subscribers(var, {result, var}, data)
          end)
      end)

    {:reply, reply, data}
  end

  def handle_call(:get_variables, _from, %{agents: agents} = data) do
    var_ids = Map.keys(agents)
    {:reply, var_ids, data}
  end

  @impl true
  def handle_cast({:on_change, _var, _change}, data) do
    {:noreply, data}
  end

  def handle_cast({:on_fail, _var}, data) do
    {:noreply, data}
  end

  def handle_cast({:on_no_change, _var}, data) do
    {:noreply, data}
  end

  def handle_cast({:subscribe, subscriptions}, %{agents: agents} = data) do
    new_data =
      subscriptions
      |> Enum.group_by(fn s -> s.variable end, fn s -> Map.delete(s, :variable) end)
      |> Map.merge(agents, fn _var, new_subscr, agent ->
        (new_subscr ++ agent.subscriptions)
        |> Enum.uniq_by(fn s -> s.pid end)
        |> then(fn updated_subscriptions ->
          Map.put(agent, :subscriptions, updated_subscriptions)
        end)
      end)
      |> then(fn updated_agents -> Map.put(data, :agents, Map.new(updated_agents)) end)

    {:noreply, new_data}
  end

  def handle_cast(:stop, %{agents: agents} = data) do
    Enum.each(agents, fn %{pid: pid} = _agent -> Process.exit(pid, :brutal_kill) end)
    {:stop, :normal, data}
  end

  defp get_agent_pid(var_id, %{agents: agents} = _data) do
    case Map.get(agents, var_id) do
      nil -> nil
      %{agent: pid} -> pid
    end
  end

  defp notify_subscribers(var, event, %{agents: agents} = _data) do
    subscriptions = Map.get(agents, var) |> Map.get(:subscriptions)
    Enum.each(subscriptions, fn s -> notify(s, event) end)
  end

  defp notify(%{pid: subscriber, events: _events} = _subscription, event) do
    ## TODO: notify based on the list of events
    send(subscriber, event)
  end
end
