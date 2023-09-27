defmodule CPSolverTest.Examples.Queens do
  use ExUnit.Case, async: false

  alias CPSolver.Examples.Queens

  ## No solutions
  test "3 Queens" do
    test_queens(3, 0, trials: 100, timeout: 50)
  end

  test "4 Queens" do
    test_queens(4, 2)
  end

  test "5 Queens" do
    test_queens(5, 10, timeout: 500)
  end

  test "6 Queens" do
    test_queens(6, 4, timeout: 500)
  end

  test "7 Queens" do
    test_queens(7, 40, timeout: 2000)
  end

  test "8 Queens" do
    test_queens(8, 92, timeout: 2000)
  end

  defp test_queens(n, expected_solutions, opts \\ []) do
    opts = Keyword.merge([timeout: 1000, trials: 1], opts)

    Enum.each(1..opts[:trials], fn _ ->
      {:ok, solver} = Queens.solve(n, opts)
      Process.sleep(opts[:timeout])
      assert Enum.all?(CPSolver.solutions(solver), fn sol -> Queens.check_solution(sol) end)
      assert CPSolver.statistics(solver).solution_count == expected_solutions
    end)
  end
end
