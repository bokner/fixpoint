defmodule CPSolverTest.Examples.TSP do
  use ExUnit.Case

  alias CPSolver.Examples.TSP

  test "wikipedia, 4 cities (https://en.wikipedia.org/wiki/File:Weighted_K4.svg)" do
    distances = [
      [0, 20, 42, 35],
      [20, 0, 30, 34],
      [42, 30, 0, 12],
      [35, 34, 12, 0]
    ]

    model = TSP.model(distances)
    {:ok, result} = CPSolver.solve_sync(model)

    assert result.status == {:optimal, [objective: 97]}
    optimal_solution = List.last(result.solutions)
    assert TSP.check_solution(optimal_solution, model)
  end
end
