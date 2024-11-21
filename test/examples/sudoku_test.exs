defmodule CPSolverTest.Examples.Sudoku do
  use ExUnit.Case, async: false

  alias CPSolver.Examples.Sudoku

  alias CPSolver.Search.VariableSelector, as: Strategy

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
      {:ok, result} =
        CPSolver.solve(Sudoku.model(puzzle_instance),
          search: {
            # Strategy.first_fail(&Enum.random/1),
            Strategy.afc({:afc_size_min, 0.75}, &List.first/1),
            :indomain_random
          },
          timeout: opts[:timeout]
        )

      Enum.each(result.solutions, &assert_solution/1)
      solution_count = result.statistics.solution_count

      assert solution_count == expected_solutions
    end)
  end

  defp assert_solution(solution) do
    assert Sudoku.check_solution(solution), "Wrong solution!"
  end
end
