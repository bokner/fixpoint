defmodule CPSolverTest.Examples.Queens do
  use ExUnit.Case, async: false

  test "4 Queens" do
    test_queens(4, 2)
  end

  test "5 Queens" do
    test_queens(5, 10, timeout: 2000)
  end

  test "6 Queens" do
    test_queens(6, 4, timeout: 2000)
  end

  test "8 Queens" do
    test_queens(8, 92, timeout: 2000)
  end

  defp test_queens(n, expected_solutions, opts \\ []) do
    opts = Keyword.merge([timeout: 1000, trials: 1], opts)

    Enum.each(1..opts[:trials], fn _ ->
      {:ok, solver} = CPSolver.Examples.Queens.solve(n, opts)
      Process.sleep(opts[:timeout])
      assert CPSolver.statistics(solver).solution_count == expected_solutions
    end)
  end
end
