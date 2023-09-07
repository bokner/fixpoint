defmodule CPSolver.Search.Strategy do
  alias CPSolver.Variable
  @callback select_variable([Variable.t()]) :: {:ok, Variable.t()} | {:error, any()}
  @callback partition(domain :: Enum.t()) :: {:ok, [Domain.t() | number()]} | {:error, any()}

  def default_strategy() do
    CPSolver.Search.Strategy.FirstFail
  end

  def all_vars_fixed_exception() do
    :all_vars_fixed
  end

  def failed_variables_in_search_exception() do
    :failed_variables_in_search
  end
end
