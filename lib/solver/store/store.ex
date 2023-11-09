defmodule CPSolver.ConstraintStore do
  @moduledoc """
  Constraint store is a key-value store, where `key` is a variable id,
  and `value` is a implementation-dependent structure that allows to
  update and keep track of variables' domains.
  """
  #################
  alias CPSolver.{Common, Variable}

  require Logger

  @type get_operation :: Common.domain_get_operation() | nil
  @type update_operation :: Common.domain_update_operation()

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

  def default_store_opts() do
    [space: self(), store_impl: default_store()]
  end

  def create_store(variables, opts \\ [])

  def create_store(variables, opts) do
    opts = Keyword.merge(default_store_opts(), opts)
    space = Keyword.get(opts, :space)
    store_impl = Keyword.get(opts, :store_impl)
    {:ok, store_handle} = store_impl.create(variables, opts)

    store = %{
      space: space,
      handle: store_handle,
      store_impl: store_impl
    }

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

  def variable_id(%Variable{id: id}) do
    id
  end

  def variable_id(id) do
    id
  end
end
