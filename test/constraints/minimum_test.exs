defmodule CPSolverTest.Constraint.Minimum do
  use ExUnit.Case, async: false

  alias CPSolver.IntVariable, as: Variable
  alias CPSolver.Model
  alias CPSolver.Constraint.Minimum
  alias CPSolver.Constraint.Factory, as: ConstraintFactory
  import CPSolver.Variable.View.Factory

  describe "Minimum constraint" do
    test "`minimum` functionality" do
      x_arr = Enum.map(1..4, fn idx -> Variable.new(0..4, name: "x#{idx}") end)
      y = Variable.new(-5..20, name: "y")

      model = Model.new([y | x_arr], [Minimum.new(y, x_arr)])

      {:ok, result} = CPSolver.solve(model)

      assert_minimum(result.solutions)
      assert result.statistics.solution_count == 625
    end

    test "Factory" do
      x_arr = Enum.map(1..4, fn idx -> Variable.new(0..4, name: "x#{idx}") end)
      {max_var, maximum_constraint} = ConstraintFactory.minimum(x_arr)

      assert Variable.min(max_var) == 0
      assert Variable.max(max_var) == 4

      model = Model.new([], [maximum_constraint])

      {:ok, result} = CPSolver.solve(model)

      assert_minimum(result.solutions)
      assert result.statistics.solution_count == 625
    end

    test "Consistent with Maximum" do
      x_arr = Enum.map(1..4, fn idx -> minus(Variable.new(0..4, name: "x#{idx}")) end)
      {negative_max_var, negative_maximum_constraint} = ConstraintFactory.minimum(x_arr)

      assert Variable.min(negative_max_var) == -4
      assert Variable.max(negative_max_var) == 0

      model = Model.new([], [negative_maximum_constraint])

      {:ok, result} = CPSolver.solve(model)

      assert_minimum(result.solutions, fn y -> -y end)
      assert result.statistics.solution_count == 625
    end

    ## Constraint check: y = max(x_array)
    ##
    defp assert_minimum(solutions, transform_fun \\ &Function.identity/1) do
      assert Enum.all?(solutions, fn [y | xs] ->
               y == Enum.map(xs, fn x -> transform_fun.(x) end) |> Enum.min()
             end)
    end
  end
end
