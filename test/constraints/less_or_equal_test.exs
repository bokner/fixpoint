defmodule CPSolverTest.Constraint.LessOrEqual do
  use ExUnit.Case, async: false

  describe "LessOrEqual" do
    alias CPSolver.Constraint.{Less, LessOrEqual}
    alias CPSolver.IntVariable, as: Variable
    alias CPSolver.Constraint
    alias CPSolver.Model

    test "less_or_equal, 2 variables" do
      x = Variable.new(0..1, name: "x")
      y = Variable.new(0..1, name: "y")
      model = Model.new([x, y], [Constraint.new(LessOrEqual, [x, y])])
      {:ok, res} = CPSolver.solve(model)

      assert length(res.solutions) == 3
      assert Enum.all?(res.solutions, fn [x_val, y_val] -> x_val <= y_val end)
    end

    test "less_or_equal, variable and constant" do
      x = Variable.new(0..4)
      upper_bound = 2
      le_constraint = LessOrEqual.new(x, upper_bound)
      model = Model.new([x], [le_constraint])
      {:ok, res} = CPSolver.solve(model)
      assert length(res.solutions) == 3
      assert Enum.all?(res.solutions, fn [x_val, _] -> x_val <= upper_bound end)
    end

    test "Less (inconsistent)" do
      x = Variable.new(1)
      y = Variable.new(1)
      less_constraint = Less.new(x, y)
      assert catch_throw({:fail, _} = Model.new([x, y], [less_constraint]))

    end
  end
end
