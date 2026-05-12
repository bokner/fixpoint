defmodule CPSolver.Search.VariableSelector.InputOrder do
  use CPSolver.Search.VariableSelector

  @impl true
  def select(variables, _data, _opts) do
    List.first(variables)
  end
end
