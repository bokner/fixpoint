defmodule CPSolver.Search.ValueSelector.Max do
  use CPSolver.Search.ValueSelector

  @impl true
  def select_value(variable) do
    Interface.max(variable)
  end
end
