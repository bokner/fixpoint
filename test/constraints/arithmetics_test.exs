defmodule CPSolverTest.Constraint.Arithmetics do
  use ExUnit.Case, async: false

  describe "Sum" do
    alias CPSolver.IntVariable, as: Variable
    alias CPSolver.DefaultDomain, as: Domain
    alias CPSolver.Constraint.Factory
    alias CPSolver.Model

    test "add 2 variables" do
      {:ok, [x,y], res} = setup_and_solve(:add)

      assert Domain.size(x.domain) * Domain.size(y.domain) == length(res.solutions)

      assert Enum.all?(res.solutions, fn [x_val, y_val, sum_val] ->
               x_val + y_val == sum_val
             end)
    end

    test "subtract 2 variables" do
      {:ok, [x,y], res} = setup_and_solve(:subtract)

      assert Domain.size(x.domain) * Domain.size(y.domain) == length(res.solutions)

      assert Enum.all?(res.solutions, fn [x_val, y_val, sum_val] ->
               x_val - y_val == sum_val
             end)
    end

    defp setup_and_solve(constraint_kind) do
      x = Variable.new(0..2, name: "x")
      y = Variable.new(0..2, name: "y")

      {_sum_var, constraint} = case constraint_kind do
        :add -> Factory.add(x, y, name: "add_x_y")
        :subtract -> Factory.subtract(x, y, name: "subtract_x_y")
      end

      model = Model.new([x, y], [constraint])
      {:ok, res} = CPSolver.solve_sync(model)
      {:ok, [x, y], res}
    end
  end
end
