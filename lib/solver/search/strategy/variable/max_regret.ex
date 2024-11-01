defmodule CPSolver.Search.VariableSelector.MaxRegret do
  alias CPSolver.Variable.Interface
  alias CPSolver.DefaultDomain, as: Domain
  alias CPSolver.Utils

  ## Choose the variable(s) with largest difference
  ## between the two smallest values in its domain.
  def select(variables, space_data) do
    largest_difference(variables, space_data)
  end

  defp largest_difference(variables, _space_data) do
    Utils.maximals(variables, &difference/1)
  end

  defp difference(variable) do
    values = Interface.domain(variable) |> Domain.to_list()
    [smallest, second_smallest] = Enum.take(values, 2)
    second_smallest - smallest
  end

end
