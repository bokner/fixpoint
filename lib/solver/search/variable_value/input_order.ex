defmodule CPSolver.Search.VariableSelector.InputOrder do
  @behaviour CPSolver.Search.VariableSelector

  @impl true
  def select_variable(variables) do
    Enum.sort_by(variables, fn %{index: idx} -> idx end)
    |> List.first()
  end
end
