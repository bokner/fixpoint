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
    {:ok, result} = CPSolver.solve(model)

    optimal_solution = List.last(result.solutions)
    assert TSP.check_solution(optimal_solution, model)

    assert result.status == {:optimal, [objective: 97]}
  end

  test "7 cities, optimality" do
    tsp_7_instance = "data/tsp/tsp_7.txt"
    model = TSP.model(tsp_7_instance)
    {:ok, result} = TSP.run(tsp_7_instance)

    assert Enum.all?(result.solutions, fn sol -> TSP.check_solution(sol, model) end)

    assert result.status == {:optimal, [objective: 56]}
  end

  test "15 cities, optimality" do
    tsp_instance = "data/tsp/tsp_15.txt"
    model = TSP.model(tsp_instance)
    {:ok, result} = TSP.run(tsp_instance)

    assert Enum.all?(result.solutions, fn sol -> TSP.check_solution(sol, model) end)
    assert result.status == {:optimal, [objective: 291]}
  end
end
