defmodule CPSolverTest.Examples.Sudoku do
  use ExUnit.Case, async: false

  alias CPSolver.Examples.Sudoku

  test "4x4" do
    test_sudoku(Sudoku.puzzles().s4x4, 2, trials: 10, timeout: 100)
  end

  test "9x9 singe solution 1" do
    test_sudoku(Sudoku.puzzles().s9x9_1, 1, timeout: 2000)
  end

  test "9x9 singe solution 2" do
    test_sudoku(Sudoku.puzzles().hard9x9, 1)
  end

  test "9x9 multiple solutions" do
    test_sudoku(Sudoku.puzzles().s9x9_5, 5, timeout: 2000)
  end

  defp test_sudoku(puzzle_instance, expected_solutions, opts \\ []) do
    opts =
      Keyword.merge([timeout: 500, trials: 1], opts)

    Enum.each(1..opts[:trials], fn _i ->
      {:ok, result} = CPSolver.solve_sync(Sudoku.model(puzzle_instance), timeout: opts[:timeout])
      Enum.each(result.solutions, &assert_solution/1)
      solution_count = result.statistics.solution_count

      assert solution_count == expected_solutions
    end)
  end

  defp assert_solution(solution) do
    assert Sudoku.check_solution(solution), "Wrong solution!"
  end
end
