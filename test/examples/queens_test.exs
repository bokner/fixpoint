defmodule CPSolverTest.Examples.Queens do
  use ExUnit.Case, async: false

  alias CPSolver.Examples.Queens

  require Logger

  ## No solutions
  test "3 Queens" do
    test_queens(3, 0)
  end

  test "4 Queens" do
    test_queens(4, 2)
  end

  test "5 Queens" do
    test_queens(5, 10)
  end

  test "6 Queens" do
    test_queens(6, 4)
  end

  test "7 Queens" do
    test_queens(7, 40)
  end

  test "8 Queens" do
    test_queens(8, 92, timeout: 200)
  end

  defp test_queens(n, expected_solutions, opts \\ []) do
    opts =
      Keyword.merge([timeout: 100, trials: 10], opts)

    Enum.each(1..opts[:trials], fn i ->
      {:ok, result} = CPSolver.solve_sync(Queens.model(n), timeout: opts[:timeout])
      Enum.each(result.solutions, &assert_solution/1)
      solution_count = result.statistics.solution_count

      assert solution_count == expected_solutions,
             "Failed on trial #{i} with #{inspect(solution_count)} out of #{expected_solutions} solution(s)"
    end)
  end

  defp assert_solution(solution) do
    assert Queens.check_solution(solution)
  end
end
