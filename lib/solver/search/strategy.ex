defmodule CPSolver.Search.Strategy do
  alias CPSolver.Variable
  @callback select_variable([Variable.t()]) :: Variable.t()
  @callback select_value(Variable.t()) :: number()

  def no_variable_choice_exception() do
    :no_variable_choice
  end

  def failed_variables_in_search_exception() do
    :failed_variables_in_search
  end
end
