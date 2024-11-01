defmodule CPSolver.Search.VariableSelector.MaxRegret do
  alias CPSolver.Variable.Interface
  alias CPSolver.DefaultDomain, as: Domain

  ## Choose the variable(s) with largest difference
  ## between the two smallest values in its domain.
  def candidates(variables, space_data) do
    largest_difference(variables, space_data)
  end

  defp largest_difference(variables, _space_data) do
    List.foldr(variables, {[], -1}, fn var, {vars, current_max} = acc ->
      difference = difference(var)

      cond do
        difference < current_max -> acc
        difference > current_max -> {[var], difference}
        difference == current_max -> {[var | vars], difference}
      end
    end)
    |> elem(0)
  end

  defp difference(variable) do
    values = Interface.domain(variable) |> Domain.to_list()
    [smallest, second_smallest] = Enum.take(values, 2)
    second_smallest - smallest
  end

  def select_variable(variables, space_data, break_even_fun \\ &List.first/1) do
    candidates(variables, space_data)
    |> break_even_fun.()
  end
end
