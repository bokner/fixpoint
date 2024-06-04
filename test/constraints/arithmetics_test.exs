defmodule CPSolverTest.Constraint.Arithmetics do
  use ExUnit.Case, async: false

  describe "Sum" do
    alias CPSolver.IntVariable, as: Variable
    alias CPSolver.Constraint.Factory
    alias CPSolver.Model

    test "add 2 variables" do
      {:ok, res} = setup_and_solve(:add)

      assert Enum.all?(res.solutions, fn [x_val, y_val, sum_val] ->
               x_val + y_val == sum_val
             end)
    end

    test "subtract 2 variables" do
      {:ok, res} = setup_and_solve(:subtract)

      assert Enum.all?(res.solutions, fn [x_val, y_val, sum_val] ->
               x_val - y_val == sum_val
             end)
    end

    defp setup_and_solve(constraint_kind) do
      x_domain = 0..2
      y_domain = 0..2
      x = Variable.new(x_domain, name: "x")
      y = Variable.new(y_domain, name: "y")

      {_sum_var, constraint} = case constraint_kind do
        :add -> Factory.add(x, y, name: "add_x_y")
        :subtract -> Factory.subtract(x, y, name: "subtract_x_y")
      end

      model = Model.new([x, y], [constraint])
      {:ok, _res} = CPSolver.solve_sync(model)
    end
  end
end
