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
    CPSolver.Store.Registry
  end

  ### Callbacks

  ## Tell basic constraints (a.k.a, domains) to a constraint store
  @callback create(variables :: Enum.t(), opts :: Keyword.t()) ::
              {:ok, Enum.t(), any()} | {:error, any()}

  ## Get variable details
  @callback get(store :: any(), variable :: Variable.t(), get_operation(), [any()]) ::
              {:ok, any()} | {:error, any()}

  @callback update(store :: any(), variable :: Variable.t(), update_operation(), [any()]) ::
              any()

  @callback update_domain(store :: any(), variable :: Variable.t(), update_operation(), [any()]) ::
              any()

  @callback dispose(store :: any(), variable :: Variable.t()) :: :ok | :not_found

  @callback domain(store :: any(), variable :: Variable.t()) :: {:ok, any()} | {:error, any()}

  @callback on_fail(variable :: Variable.t()) :: any()

  @callback on_no_change(variable :: Variable.t()) :: any()

  @callback on_change(
              variable :: Variable.t(),
              change :: :fixed | :min_change | :max_change | :domain_change
            ) :: any()

  @callback get_variables(store :: any()) :: [any()]

  ### API
  defmacro __using__(_) do
    quote do
      @behaviour CPSolver.ConstraintStore
      require Logger

      def update(store, variable, operation, args) do
        update_domain(store, variable, operation, args)
        |> tap(fn
          :fail -> on_fail(variable)
          :no_change -> on_no_change(variable)
          domain_change -> on_change(variable, domain_change)
        end)
      end

      def on_change(var, domain_change) do
        publish(var, domain_change)
        |> tap(fn _ ->
          Logger.debug("Domain change (#{domain_change}) for #{inspect(var.id)}")
          maybe_unsubscribe_all(domain_change, var)
        end)
      end

      def on_fail(var) do
        Logger.debug("Failure for variable #{inspect(var.id)}")
        ## TODO: notify space (and maybe don't notify propagators)
        publish(var, :fail)
      end

      def on_no_change(_var) do
        :ok
      end

      defp publish(variable, event) do
        Variable.publish(variable, {event, variable.id})
      end

      defp maybe_unsubscribe_all(:fixed, var) do
        Enum.each(Variable.subscribers(var), fn pid -> Variable.unsubscribe(pid, var) end)
      end

      defp maybe_unsubscribe_all(_, _var) do
        :ok
      end

      defoverridable update: 4
      defoverridable on_change: 2
      defoverridable on_fail: 1
      defoverridable on_no_change: 1
    end
  end
end
