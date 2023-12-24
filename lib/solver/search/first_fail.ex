defmodule CPSolver.Search.VariableSelector.FirstFail do
  @behaviour CPSolver.Search.VariableSelector
  alias CPSolver.Variable.Interface

  @impl true
  def select_variable(variables) do
    Enum.min_by(variables, fn var -> Interface.size(var) end)
  end
end
