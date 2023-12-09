defmodule CPSolverTest.Examples.SendMoreMoney do
  use ExUnit.Case

  alias CPSolver.Examples.SendMoreMoney

  test "order" do
    letters = [S, E, N, D, M, O, R, Y]
    expected_solution = [9, 5, 6, 7, 1, 0, 8, 2]

    {:ok, result} = CPSolver.solve_sync(SendMoreMoney.model())

    ## Single solution
    assert length(result.solutions) == 1
    ## As expected
    assert Enum.zip(letters, expected_solution) ==
             Enum.zip(result.variables, hd(result.solutions))

    ## Solution checker
    assert SendMoreMoney.check_solution(hd(result.solutions))
  end
end
