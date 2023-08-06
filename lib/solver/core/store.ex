defmodule CPSolver.ConstraintStore do
  @moduledoc """
  Constraint store is a key-value store, where `key` is a variable id,
  and `value` is a implementation-dependent structure that allows to
  update and keep track of variables' domains.
  """
  #################
  alias CPSolver.Common

  @type get_operation :: Common.domain_get_operation() | nil
  @type update_operation :: Common.domain_update_operation()

  def default_store() do
    CPSolver.Store.Registry
  end

  ### Callbacks

  ## Tell basic constraints (a.k.a, domains) to a constraint store
  @callback create(space :: any(), variables :: Enum.t()) :: {:ok, any()} | {:error, any()}

  ## Get variable details
  @callback get(store :: any(), variable_id :: any(), get_operation() | {get_operation(), any()}) ::
              {:ok, any()} | {:error, any()}

  @callback update_domain(store :: any(), variable_id :: any(), {update_operation(), any()}) ::
              any()

  ### API
end
