defmodule CPSolver.Search.ValueSelector.Split do
  use CPSolver.Search.ValueSelector

  @moduledoc """
  Bisect the domain.
  """
  import CPSolver.Utils

  @impl true
  def select_value(variable) do
    variable
    |> domain_values()
    |> then(fn values ->
      Enum.at(values, div(MapSet.size(values) - 1, 2))
    end)
  end

  @impl true
  def partition(value) do
    [
      fn domain ->
        Domain.removeAbove(domain, value) end,
      fn domain ->
        Domain.removeBelow(domain, value + 1) end,
    ]
  end
end
