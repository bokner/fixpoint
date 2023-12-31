defmodule CPSolverTest.Constraint.AllDifferent.FWC do
  use ExUnit.Case, async: false

  describe "AllDifferentFWC" do
    alias CPSolver.Constraint.AllDifferent.FWC, as: AllDifferentFWC
    alias CPSolver.IntVariable
    alias CPSolver.Constraint
    alias CPSolver.Model

    test "produces all possible permutations" do
      domain = 1..3
      variables = Enum.map(1..3, fn _ -> IntVariable.new(domain) end)

      model = Model.new(variables, [Constraint.new(AllDifferentFWC, variables)])

      {:ok, solver} = CPSolver.solve(model)

      Process.sleep(100)
      assert CPSolver.statistics(solver).solution_count == 6

      assert CPSolver.solutions(solver) |> Enum.sort() == [
               [1, 2, 3],
               [1, 3, 2],
               [2, 1, 3],
               [2, 3, 1],
               [3, 1, 2],
               [3, 2, 1]
             ]
    end
  end
end
