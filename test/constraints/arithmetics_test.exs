defmodule CPSolverTest.Constraint.Arithmetics do
  use ExUnit.Case, async: false

  describe "Arithmetics" do
    alias CPSolver.IntVariable, as: Variable
    alias CPSolver.Constraint.Factory, as: ConstraintFactory
    alias CPSolver.Variable.View.Factory, as: ViewFactory
    alias CPSolver.Model
    alias CPSolver.Constraint.Equal

    test "add 2 variables" do
      {:ok, res} = setup_and_solve(:add_variable)

      assert Enum.all?(res.solutions, fn [x_val, y_val, sum_val] ->
               x_val + y_val == sum_val
             end)
    end

    test "subtract 2 variables" do
      {:ok, res} = setup_and_solve(:subtract_variable)

      assert Enum.all?(res.solutions, fn [x_val, y_val, sum_val] ->
               x_val - y_val == sum_val
             end)
    end

    test "add variable and constant" do
      x_domain = 1..10
      c = 3
      x = Variable.new(x_domain, name: "x")
      model = Model.new([x], [Equal.new(ViewFactory.inc(x, c), 10)])
      {:ok, res} = CPSolver.solve(model)

      assert length(res.solutions) == 1
      assert hd(hd(res.solutions)) == 10 - c
    end

    defp setup_and_solve(constraint_kind)
         when constraint_kind in [:add_variable, :subtract_variable] do
      x_domain = 0..2
      y_domain = 0..2
      x = Variable.new(x_domain, name: "x")
      y = Variable.new(y_domain, name: "y")

      {_sum_var, constraint} =
        case constraint_kind do
          :add_variable -> ConstraintFactory.add(x, y)
          :subtract_variable -> ConstraintFactory.subtract(x, y)
        end

      model = Model.new([x, y], [constraint])
      {:ok, _res} = CPSolver.solve(model)
    end
  end
end
