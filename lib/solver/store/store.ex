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

  def default_store() do
    CPSolver.Store.Local
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
              change :: :fixed | :min_change | :max_change | :domain_change
            ) :: any()

  @callback get_variables(store :: any()) :: [any()]

  @callback subscribe(
              store :: any(),
              subscriptions :: [%{pid: pid(), variable: any(), events: [any()]}]
            ) :: :ok | :not_found

  ### API
  defmacro __using__(_) do
    quote do
      @behaviour CPSolver.ConstraintStore
      @domain_changes CPSolver.Common.domain_changes()
      require Logger

      def update(store, variable, operation, args) do
        update_domain(store, variable, operation, args)
        |> tap(fn
          :fail -> on_fail(store, variable)
          :no_change -> on_no_change(store, variable)
          change when change in @domain_changes -> on_change(store, variable, change)
        end)
      end

      defoverridable update: 4
    end
  end

  def create_store(variables, store_impl \\ default_store()) do
    {:ok, store_instance} = store_impl.create(variables)

    {:ok,
     Enum.map(variables, fn var ->
       var
       |> Map.put(:id, var.id)
       |> Map.put(:name, var.name)
       |> Map.put(:store, store_instance)
     end), store_instance, store_impl}
  end
end
