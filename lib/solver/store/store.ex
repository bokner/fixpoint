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
    CPSolver.Store.Direct
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
  @callback on_fix(store :: any(), variable :: Variable.t(), value :: any()) :: any()

  ### API
  defmacro __using__(_) do
    quote do
      @behaviour CPSolver.ConstraintStore
      @domain_events CPSolver.Common.domain_events()
      alias CPSolver.ConstraintStore
      require Logger

      def update(store, variable, operation, args) do
        update_domain(store, variable, operation, args)
        |> tap(fn
          :fail ->
            on_fail(store, variable)

          {:fixed, value} ->
            on_fix(store, variable, value)

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

    {:ok, store}
  end

  def domain(variable) do
    domain(variable.store, variable)
  end

  def domain(%{handle: handle, store_impl: store_impl} = _store, variable) do
    store_impl.domain(handle, variable)
  end

  def get(store, variable, operation, args \\ [])

  def get(%{handle: handle, store_impl: store_impl} = _store, variable, operation, args) do
    store_impl.get(handle, variable, operation, args)
  end

  def update(store, variable, operation, args \\ [])

  def update(
        %{handle: handle, store_impl: store_impl} = _store,
        variable,
        operation,
        args
      ) do
    store_impl.update(handle, variable, operation, args)
  end

  def dispose(%{handle: handle, store_impl: store_impl} = _store, variables) do
    store_impl.dispose(handle, variables)
  end

end
