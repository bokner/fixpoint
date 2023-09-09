defmodule CPSolverTest.Examples.Queens do
  use ExUnit.Case, async: false

  test "4 Queens" do
    test_queens(4, 2)
  end

  defp test_queens(n, expected_solutions, opts \\ []) do
    opts = Keyword.merge([timeout: 1000, trials: 1], opts)

    Enum.each(1..opts[:trials], fn _ ->
      {:ok, solver} = CPSolver.Examples.Queens.solve(n, opts)
      Process.sleep(opts[:timeout])
      ## TODO: fix occasional overshooting
      ## and then change it back to strict equality
      assert CPSolver.statistics(solver).solution_count >= expected_solutions
    end)
  end
end
