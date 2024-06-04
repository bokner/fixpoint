defmodule CPSolver.Search.ValueSelector.Min do
  @behaviour CPSolver.Search.ValueSelector
  alias CPSolver.Variable.Interface

  @impl true
  def select_value(variable) do
    Interface.min(variable)
  end
end
