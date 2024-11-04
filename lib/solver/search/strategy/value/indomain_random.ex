defmodule CPSolver.Search.ValueSelector.Random do
  @behaviour CPSolver.Search.ValueSelector
  import CPSolver.Utils

  @impl true
  def select_value(variable) do
    variable
    |> domain_values()
    |> Enum.random()
  end
end
