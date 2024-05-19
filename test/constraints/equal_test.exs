defmodule CPSolverTest.Constraint.Equal do
  use ExUnit.Case, async: false

  describe "LessOrEqual" do
    alias CPSolver.Constraint.Equal
    alias CPSolver.IntVariable, as: Variable
    alias CPSolver.Model

    test "equal, 2 variables" do
      x = Variable.new(0..1, name: "x")
      y = Variable.new(0..1, name: "y")
      z = Variable.new(2..4, name: "z")
      satisfiable_model = Model.new([x, y], [Equal.new([x, y])])
      {:ok, res} = CPSolver.solve_sync(satisfiable_model)

      assert length(res.solutions) == 2
      assert Enum.all?(res.solutions, fn [x_val, y_val] -> x_val == y_val end)

      unsatisfiable_model = Model.new([x, y, z], [Equal.new([x, y]), Equal.new([y, z])])
      {:ok, res} = CPSolver.solve_sync(unsatisfiable_model)
      assert res.status == :unsatisfiable
    end

    test "variable and constant" do
      x = Variable.new(0..4)
      satisfiable_value = 3
      equal_constraint = Equal.new(x, satisfiable_value)
      satisfiable_model = Model.new([x], [equal_constraint])
      {:ok, res} = CPSolver.solve_sync(satisfiable_model)
      assert length(res.solutions) == 1
      assert hd(hd(res.solutions)) == satisfiable_value

      unsatisfiable_value = -1
      equal_constraint = Equal.new(x, unsatisfiable_value)
      unsatisfiable_model = Model.new([x], [equal_constraint])
      {:ok, res} = CPSolver.solve_sync(unsatisfiable_model)
      assert res.status == :unsatisfiable

    end
  end
end
