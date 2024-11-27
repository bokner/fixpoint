defmodule CPSolver.Search.VariableSelector.InputOrder do
  use CPSolver.Search.VariableSelector

  @impl true
  def select(variables, _data, _opts) do
    Enum.sort_by(variables, fn %{index: idx} -> idx end)
    |> List.first()
  end
end
