defmodule CPSolverTest.Examples.Sudoku do
  use ExUnit.Case, async: false

  alias CPSolver.Examples.Sudoku
  alias CPSolver.Examples.Utils, as: ExamplesUtils

  test "4x4" do
    test_sudoku(Sudoku.puzzles().s4x4, 2, trials: 10, timeout: 100)
  end

  test "9x9 singe solution 1" do
    test_sudoku(Sudoku.puzzles().s9x9_1, 1, trials: 1, timeout: 2000)
  end

  test "9x9 singe solution 2" do
    test_sudoku(Sudoku.puzzles().hard9x9, 1, trials: 1, timeout: 500)
  end

  test "9x9 multiple solutions" do
    test_sudoku(Sudoku.puzzles().s9x9_5, 5, trials: 1, timeout: 500)
  end

  defp test_sudoku(puzzle_instance, expected_solutions, opts \\ []) do
    opts =
      Keyword.merge([timeout: 1000, trials: 1], opts)
      |> Keyword.put(:solution_handler, ExamplesUtils.notify_client_handler())

    Enum.each(1..opts[:trials], fn _ ->
      ExamplesUtils.flush_solutions()
      {:ok, solver} = Sudoku.solve(puzzle_instance, opts)
      ExamplesUtils.wait_for_solutions(expected_solutions, opts[:timeout], &assert_solution/1)
      Process.sleep(100)
      assert CPSolver.statistics(solver).solution_count == expected_solutions
    end)
  end

  defp assert_solution(solution) do
    assert Sudoku.check_solution(solution)
  end
end
