defmodule CpSolverTest do
  use ExUnit.Case

  alias CPSolver.IntVariable
  alias CPSolver.Constraint.NotEqual

  test "Solves CSP with 2 variables and a single constraint" do
    x = IntVariable.new([1, 2])
    y = IntVariable.new([0, 1])

    model = %{
      variables: [x, y],
      constraints: [{NotEqual, x, y}]
    }

    solution = CPSolver.solve(model)

    Process.sleep(100)
    # assert Enum.sort_by(solution.assignments, fn rec -> rec.x end) == [
    #          %{x: 0, y: 1},
    #          %{x: 0, y: 2},
    #          %{x: 1, y: 2}
    #        ]
  end
end
