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

      {_sum_var, sum_constraint} = Factory.sum([x, y, z])

      model = Model.new([x, y, z], [sum_constraint])
      {:ok, res} = CPSolver.solve(model)

      assert 8 == length(res.solutions)

      assert Enum.all?(res.solutions, fn s ->
               Enum.sum(Enum.take(s, length(s) - 1)) == List.last(s)
             end)
    end

    test "sum (mixed arguments)" do
      c1 = 3
      c2 = -4
      c3 = 5

      x = Variable.new(0..1, name: "x")
      y = Variable.new(0..1, name: "y")
      z = Variable.new(0..1, name: "z")
      {_sum_var, sum_constraint} = Factory.sum([x, c1, y, c2, c3, z])

      model = Model.new([x, y, z], [sum_constraint])
      {:ok, res} = CPSolver.solve(model)

      assert 8 == length(res.solutions)

      assert Enum.all?(res.solutions, fn s ->
               Enum.sum(Enum.take(s, length(s) - 1)) + c1 + c2 + c3 == List.last(s)
             end)
    end
  end
end
