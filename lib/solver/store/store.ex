defmodule CPSolver.ConstraintStore do
  @moduledoc """
  Constraint store is a key-value store, where `key` is a variable id,
  and `value` is a implementation-dependent structure that allows to
  update and keep track of variables' domains.
  """
  #################
  alias CPSolver.Common
  alias CPSolver.Variable

  @type get_operation :: Common.domain_get_operation() | nil
  @type update_operation :: Common.domain_update_operation()

  @mandatory_notifications [:fixed, :fail]
  def default_store() do
    CPSolver.Store.ETS
  end

  ### Callbacks

  ## Tell basic constraints (a.k.a, domains) to a constraint store
  @callback create(variables :: Enum.t(), opts :: Keyword.t()) ::
              {:ok, any()} | {:error, any()}

  ## Get variable details
  @callback get(store :: any(), variable :: Variable.t(), get_operation(), [any()]) ::
              {:ok, any()} | {:error, any()}

  @callback update(store :: any(), variable :: Variable.t(), update_operation(), [any()]) ::
              any()

  @callback update_domain(store :: any(), variable :: Variable.t(), update_operation(), [any()]) ::
              any()

  @callback dispose(store :: any(), variables :: [Variable.t()]) :: :ok | :not_found

  @callback domain(store :: any(), variable :: Variable.t()) :: {:ok, any()} | {:error, any()}

  @callback on_fail(store :: any(), variable :: Variable.t()) :: any()

  @callback on_no_change(store :: any(), variable :: Variable.t()) :: any()

  @callback on_change(
              store :: any(),
              variable :: Variable.t(),
              change :: Common.domain_change()
            ) :: any()

  @callback get_variables(store :: any()) :: [any()]

  @callback subscribe(
              store :: any(),
              subscriptions :: [%{pid: pid(), variable: any(), events: [any()]}]
            ) :: :ok | :not_found

  @domain_events CPSolver.Common.domain_events()

  ### API
  defmacro __using__(_) do
    quote do
      @behaviour CPSolver.ConstraintStore
      @domain_events CPSolver.Common.domain_events()
      require Logger

      def update(store, variable, operation, args) do
        update_domain(store, variable, operation, args)
        |> tap(fn
          :fail ->
            on_fail(store, variable)

          :no_change ->
            on_no_change(store, variable)

          change when change in @domain_events ->
            on_change(store, variable, change)
        end)
      end

      defoverridable update: 4
    end
  end

  def create_store(variables) do
    create_store(variables, default_store(), self())
  end

  def create_store(variables, store_impl) when is_atom(store_impl) do
    create_store(variables, store_impl, self())
  end

  

  def create_store(variables, store_impl, space) do
    {:ok, store_handle} = store_impl.create(variables, space: space)
    store = %{space: space, handle: store_handle, store_impl: store_impl}

    {:ok,
     Enum.map(variables, fn var ->
       var
       |> Map.put(:id, var.id)
       |> Map.put(:name, var.name)
       |> Map.put(:store, store)
     end), store}
  end

  def domain(%{handle: handle, store_impl: store_impl} = _store, variable) do
    store_impl.domain(handle, variable)
  end

  def get(%{handle: handle, store_impl: store_impl} = _store, variable, operation, args \\ []) do
    store_impl.get(handle, variable, operation, args)
  end

  def subscribe(%{handle: handle, store_impl: store_impl} = _store, variables) do
    store_impl.subscribe(handle, variables)
  end

  def update(
        %{handle: handle, store_impl: store_impl} = _store,
        variable,
        operation,
        args \\ []
      ) do
    store_impl.update(handle, variable, operation, args)
  end

  def get_variables(%{handle: handle, store_impl: store_impl} = _store) do
    store_impl.get_variables(handle)
  end

  def dispose(%{handle: handle, store_impl: store_impl} = _store, variables) do
    store_impl.dispose(handle, variables)
  end

  def normalize_subscription(%{variable: variable, events: events} = subscription) do
    %{subscription | variable: variable_id(variable), events: normalize_events(events)}
  end

  def notify(_variable, :no_change) do
    :ignore
  end

  def notify(variable, :fail) do
    notify_space(variable, :fail)
  end

  def notify(%{id: var_id, subscriptions: subscriptions} = variable, event)
      when event in @domain_events do
    affected_subscriber_pids =
      Enum.flat_map(subscriptions, fn s -> (notify_subscriber?(s, event) && [s.pid]) || [] end)

    notify_space(variable, {event, affected_subscriber_pids})
  end

  defp notify_subscriber?(%{events: events} = _subscription, event) do
    event in (@mandatory_notifications ++ events)
  end

  defp notify_space(%{id: var_id, store: store} = _variable, :fail) do
    notify_process(store.space, var_id, :fail)
  end

  defp notify_space(
         %{id: var_id, store: store} = _variable,
         {_domain_change, propagator_pids} = event
       )
       when is_list(propagator_pids) do
    length(propagator_pids) > 0 && notify_process(store.space, var_id, event)
  end

  defp notify_process(pid, var_id, event) do
    event = {event, var_id}
    send(pid, event)
  end

  def variable_id(%Variable{id: id}) do
    id
  end

  def variable_id(id) do
    id
  end

  defp normalize_events(events) do
    ## :fixed and :fail are mandatory
    [:fixed, :fail | events]
    |> Enum.uniq()
  end
end
