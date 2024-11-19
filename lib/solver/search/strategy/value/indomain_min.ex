defmodule CPSolver.Search.ValueSelector.Min do
  use CPSolver.Search.ValueSelector

  @impl true
  def select_value(variable) do
    Interface.min(variable)
  end
end
