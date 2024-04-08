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

    optimal_solution = List.last(result.solutions)
    assert TSP.check_solution(optimal_solution, model)

    assert result.status == {:optimal, [objective: 97]}
  end

  test "7 cities, optimality" do
    model = TSP.model("data/tsp/tsp_7.txt")
    {:ok, result} = CPSolver.solve_sync(model)

    optimal_solution = List.last(result.solutions)
    assert TSP.check_solution(optimal_solution, model)

    assert result.status == {:optimal, [objective: 56]}
  end

  test "15 cities, first few solutions" do
    model = TSP.model("data/tsp/tsp_15.txt")
    {:ok, result} =
      CPSolver.solve_sync(model,
        stop_on: {:max_solutions, 3},
        timeout: 5_000,
        max_space_threads: 12
      )

    assert Enum.all?(result.solutions, fn sol -> TSP.check_solution(sol, model) end)
    assert length(result.solutions) >= 3
  end
end
