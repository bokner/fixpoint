defmodule CPSolverTest.Examples.Queens do
  use ExUnit.Case, async: false

  alias CPSolver.Examples.Queens
  alias CPSolver.Examples.Utils, as: ExamplesUtils

  require Logger

  ## No solutions
  test "3 Queens" do
    test_queens(3, 0, trials: 100, timeout: 100)
  end

  test "4 Queens" do
    test_queens(4, 2, trials: 10, timeout: 1000)
  end

  test "5 Queens" do
    test_queens(5, 10, trials: 10, timeout: 500)
  end

  test "6 Queens" do
    test_queens(6, 4, trials: 10, timeout: 500)
  end

  test "7 Queens" do
    test_queens(7, 40, trials: 1, timeout: 1000)
  end

  test "8 Queens" do
    test_queens(8, 92, trials: 10, timeout: 1000)
  end

  defp test_queens(n, expected_solutions, opts \\ []) do
    opts =
      Keyword.merge([timeout: 1000, trials: 1], opts)
      |> Keyword.put(:solution_handler, ExamplesUtils.notify_client_handler())

    Enum.each(1..opts[:trials], fn i ->
      ExamplesUtils.flush_solutions()
      {:ok, solver} = Queens.solve(n, opts)

      num_solutions =
        ExamplesUtils.wait_for_solutions(expected_solutions, opts[:timeout], &assert_solution/1)

      Process.sleep(10)
      solution_count = CPSolver.statistics(solver).solution_count

      assert solution_count == expected_solutions,
             "Failed on trial #{i} with #{inspect(solution_count)} out of #{expected_solutions} solution(s)"
    end)
  end

  defp assert_solution(solution) do
    assert Queens.check_solution(solution)
  end
end
