defmodule CPSolverTest.Constraint.Circuit do
  use ExUnit.Case, async: false

  describe "Circuit" do
    alias CPSolver.Constraint.Circuit
    alias CPSolver.IntVariable
    alias CPSolver.Constraint
    alias CPSolver.Model

    test "produces all possible circuits" do
      n = 5
      domain = 0..(n - 1)
      variables = Enum.map(1..n, fn _ -> IntVariable.new(domain) end)

      model = Model.new(variables, [Constraint.new(Circuit, variables)])

      {:ok, solver} = CPSolver.solve(model)
      assert length(solver.solutions) == Math.factorial(n - 1)
    end
  end
end
