defmodule CPSolverTest.Constraint.LessOrEqual do
  use ExUnit.Case, async: false

  describe "LessOrEqual" do
    alias CPSolver.Constraint.LessOrEqual
    alias CPSolver.IntVariable, as: Variable
    alias CPSolver.Constraint
    alias CPSolver.Model

    test "less_or_equal" do
      x = Variable.new(0..1, name: "x")
      y = Variable.new(0..1, name: "y")
      model = Model.new([x, y], [Constraint.new(LessOrEqual, [x, y])])
      {:ok, res} = CPSolver.solve_sync(model)

      assert length(res.solutions) == 3
      assert Enum.all?(res.solutions, fn [x_val, y_val] -> x_val <= y_val end)
    end
  end
end
