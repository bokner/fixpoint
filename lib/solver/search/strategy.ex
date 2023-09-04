defmodule CPSolver.Search.Strategy do
  alias CPSolver.Variable
  @callback select_variable([Variable.t()]) :: Variable.t()
  @callback partition(domain :: Enum.t()) :: [Domain.t() | number()]

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
