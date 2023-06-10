defmodule CpSolverTest do
  use ExUnit.Case

  alias CPSolver.IntVariable
  alias CPSolver.Constraint.NotEqual

  test "Solves CSP with 2 variables and a single constraint" do
    x = IntVariable.make([1, 2])
    y = IntVariable.make([0, 1])

    model = %{
      variables: [x, y],
      constraints: [{NotEqual, x, y}]
    }

    search = nil

    solution = CPSolver.solve(model, search)

    assert Enum.sort_by(solution.assignments, fn rec -> rec.x end) == [
             %{x: 0, y: 1},
             %{x: 0, y: 2},
             %{x: 1, y: 2}
           ]
  end
end
