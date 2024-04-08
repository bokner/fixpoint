defmodule CPSolverTest.Constraint.Sum do
  use ExUnit.Case, async: false

  describe "Sum" do
    alias CPSolver.IntVariable, as: Variable
    alias CPSolver.Constraint.Factory
    alias CPSolver.Model

    test "sum (3 variables)" do
      x = Variable.new(0..1, name: "x")
      y = Variable.new(0..1, name: "y")
      z = Variable.new(0..1, name: "z")

      {_sum_var, sum_constraint} = Factory.sum([x, y, z], name: "sum")

      model = Model.new([x, y, z], [sum_constraint])
      {:ok, res} = CPSolver.solve_sync(model)

      assert 8 == length(res.solutions)

      assert Enum.all?(res.solutions, fn s ->
               Enum.sum(Enum.take(s, length(s) - 1)) == List.last(s)
             end)
    end
  end
end
