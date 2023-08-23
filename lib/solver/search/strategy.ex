defmodule CPSolver.Search.Strategy do
  alias CPSolver.Variable
  @callback select_variable([Variable.t()]) :: Variable.t()
  @callback partition(domain :: Enum.t()) :: [Domain.t() | number()]

  def default_strategy() do
    CPSolver.Search.Strategy.FirstFail
  end

  def no_variable_choice_exception() do
    :no_variable_choice
  end

  def failed_variables_in_search_exception() do
    :failed_variables_in_search
  end
end
