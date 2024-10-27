defmodule CPSolver.Search.ValueSelector.Max do
  @behaviour CPSolver.Search.ValueSelector
  alias CPSolver.Variable.Interface

  @impl true
  def select_value(variable) do
    Interface.max(variable)
  end
end
