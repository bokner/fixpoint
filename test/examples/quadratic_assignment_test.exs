defmodule CPSolverTest.Examples.QAP do
  use ExUnit.Case

  alias CPSolver.Examples.QAP

  test "small instance (n = 4)" do
    distances = [
      [0, 22, 53, 53],
      [22, 0, 40, 62],
      [53, 40, 0, 55],
      [53, 62, 55, 0]
    ]

    weights = [
      [0, 3, 0, 2],
      [3, 0, 0, 1],
      [0, 0, 0, 4],
      [2, 1, 4, 0]
    ]

    qap_model = QAP.model(distances, weights)
    {:ok, results} = CPSolver.solve(qap_model)

    assert Enum.all?(results.solutions, fn solution ->
             QAP.check_solution(solution, distances, weights)
           end)

    optimal_solution = List.last(results.solutions)

    objective_variable_index =
      Enum.find_index(results.variables, fn name -> name == qap_model.extra.total_cost_var_id end)

    assert results.objective == Enum.at(optimal_solution, objective_variable_index)
  end
end
