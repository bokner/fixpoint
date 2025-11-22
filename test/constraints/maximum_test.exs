defmodule CPSolverTest.Constraint.Maximum do
  use ExUnit.Case, async: false

  alias CPSolver.IntVariable, as: Variable
  alias CPSolver.Model
  alias CPSolver.Constraint.Maximum
  alias CPSolver.Constraint.Factory, as: ConstraintFactory

  describe "Maximum constraint" do
    test "`maximum` functionality" do
      x_arr = Enum.map(1..4, fn idx -> Variable.new(0..4, name: "x#{idx}") end)
      y = Variable.new(-5..20, name: "y")

      model = Model.new([y | x_arr], [Maximum.new(y, x_arr)])

      {:ok, result} = CPSolver.solve(model)

      assert_maximum(result.solutions)
      assert result.statistics.solution_count == 625
    end

    test "Factory" do
      x_arr = Enum.map(1..4, fn idx -> Variable.new(0..4, name: "x#{idx}") end)
      {max_var, maximum_constraint} = ConstraintFactory.maximum(x_arr)

      assert Variable.min(max_var) == 0
      assert Variable.max(max_var) == 4

      model = Model.new([], [maximum_constraint])

      {:ok, result} = CPSolver.solve(model)

      assert_maximum(result.solutions)
      assert result.statistics.solution_count == 625
    end

    ## Constraint check: y = max(x_array)
    ##
    defp assert_maximum(solutions) do
      assert Enum.all?(solutions, fn [y | xs] ->
               y == Enum.max(xs)
             end)
    end
  end
end
