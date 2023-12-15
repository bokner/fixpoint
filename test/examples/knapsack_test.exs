defmodule CPSolverTest.Examples.Knapsack do
  use ExUnit.Case

  alias CPSolver.Examples.Knapsack

  test "small knapsack" do
    values = [8, 10, 15, 4]
    weights = [4, 5, 8, 3]
    capacity = 11
    {:ok, results} = CPSolver.solve_sync(Knapsack.model(values, weights, capacity))
    objective_value = results.objective

    assert Enum.all?(results.solutions, fn solution ->
             Knapsack.check_solution(solution, objective_value, values, weights, capacity)
           end)

    optimal_solution = List.last(results.solutions)

    objective_variable_index =
      Enum.find_index(results.variables, fn name -> name == "total_value" end)

    assert objective_value == Enum.at(optimal_solution, objective_variable_index)
  end
end
