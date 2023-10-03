defmodule CPSolverTest.Examples.Sudoku do
  use ExUnit.Case, async: false

  alias CPSolver.Examples.Sudoku

  test "4x4" do
    test_sudoku(Sudoku.puzzles().s4x4, 2, trials: 10, timeout: 100)
  end

  test "9x9 singe solution 1" do
    test_sudoku(Sudoku.puzzles().s9x9_1, 1, trials: 1, timeout: 1000)
  end

  test "9x9 singe solution 2" do
    test_sudoku(Sudoku.puzzles().hard9x9, 1, trials: 1, timeout: 500)
  end

  test "9x9 multiple solutions" do
    test_sudoku(Sudoku.puzzles().s9x9_5, 5, trials: 1, timeout: 500)
  end

  defp test_sudoku(puzzle_instance, expected_solutions, opts \\ []) do
    opts = Keyword.merge([timeout: 1000, trials: 1], opts)

    Enum.each(1..opts[:trials], fn _ ->
      {:ok, solver} = Sudoku.solve(puzzle_instance, opts)
      Process.sleep(opts[:timeout])
      assert Enum.all?(CPSolver.solutions(solver), fn sol -> Sudoku.check_solution(sol) end)
      assert CPSolver.statistics(solver).solution_count == expected_solutions
    end)
  end
end
