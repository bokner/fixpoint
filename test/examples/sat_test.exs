defmodule CPSolverTest.Examples.SatSolver do
  @moduledoc """

  Most test cases are borrowed from:
  https://github.com/ash-project/simple_sat/blob/main/test/simple_sat_test.exs

  """

  use ExUnit.Case

  alias CPSolver.Examples.SatSolver

  test "simple unsatisfiable" do
    assert_unsatisfiable([[1], [-1]])
  end

  test "slightly more complex unsatisfiable" do
    assert_unsatisfiable([[1, 2], [-1, -2], [1], [2]])
  end

  test "single variable" do
    assert [1] = SatSolver.solve([[1]])
  end

  test "three variables" do
    assert_satisfiable([[1, 3], [2], [1, -2, 3]])
  end

  test "many single-variable clauses" do
    assert_satisfiable([[7], [-8], [6], [-5], [-4], [-3], [2], [-1]])
  end

  test "bigger instance" do
    clauses = [
      [1],
      [-3],
      [-7],
      [6],
      [-5],
      [-4],
      [3, 2],
      [1, 2],
      [-7, -6, 5, 4, 3, -1, -2]
    ]
    assert_satisfiable(clauses)
  end

  test "voting (https://github.com/bitwalker/picosat_elixir/blob/main/README.md#example)" do
    assert MapSet.new([-2, 1, 3]) == SatSolver.solve([
      [1, 2, -3],
      [2, 3],
      [-2],
      [-1, 3]
    ]) |> SatSolver.to_cnf()
  end

  @tag :slow
  test "2 instances (50 vars, 218 clauses) from Dimacs" do
    assert_satisfiable(:sat50_218)
    assert_unsatisfiable(:unsat50_218)
  end

  defp assert_satisfiable(clauses) do
    solution = SatSolver.solve(clauses)
    assert SatSolver.check_solution(solution, clauses)
  end

  defp assert_unsatisfiable(clauses) do
    assert :unsatisfiable == SatSolver.solve(clauses)
  end
end
