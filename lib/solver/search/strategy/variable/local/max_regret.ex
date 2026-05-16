defmodule CPSolver.Search.VariableSelector.MaxRegret do
  use CPSolver.Search.VariableSelector
  alias CPSolver.Utils
  alias CPSolver.Search.Utils, as: SearchUtils

  ## Choose the variable(s) with largest difference
  ## between the two smallest values in its domain.
  @impl true
  def select(space_data, _opts) do
    largest_difference(space_data)
  end

  defp largest_difference(space_data) do
    SearchUtils.maximals(space_data, &difference/1)
  end

  defp difference(variable) do
    values = Utils.domain_values(variable)
    [smallest, second_smallest] = Enum.take(values, 2)
    second_smallest - smallest
  end
end
