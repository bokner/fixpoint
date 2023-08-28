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
  @callback create(space :: any(), variables :: Enum.t()) :: {:ok, any()} | {:error, any()}

  ## Get variable details
  @callback get(store :: any(), variable :: Variable.t(), get_operation(), [any()]) ::
              {:ok, any()} | {:error, any()}

  @callback update(store :: any(), variable :: Variable.t(), update_operation(), [any()]) ::
              any()

  @callback dispose(space :: any(), variable :: Variable.t()) :: :ok | :not_found

  @callback domain(store :: any(), variable :: Variable.t()) :: {:ok, any()} | {:error, any()}
  @callback get_variables(space :: any()) :: [any()]

  ### API
end
