defmodule CPSolver.Search.ValueSelector.Random do
  @behaviour CPSolver.Search.ValueSelector
  alias CPSolver.Variable.Interface
  alias CPSolver.DefaultDomain, as: Domain

  @impl true
  def select_value(variable) do
    variable
    |> Interface.domain()
    |> Domain.to_list()
    |> Enum.random()
  end
end
