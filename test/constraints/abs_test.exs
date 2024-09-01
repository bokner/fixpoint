defmodule CPSolverTest.Constraint.Absolute do
  use ExUnit.Case, async: false

  describe "Absolute" do
    alias CPSolver.Constraint.Absolute
    alias CPSolver.IntVariable, as: Variable
    alias CPSolver.Variable.Interface
    alias CPSolver.Model
    alias CPSolver.Constraint.Factory, as: ConstraintFactory

    ~c"""
    MiniZinc model (for verification):

    var -2..2: x;
    var -2..2: y;
    constraint y = abs(x);

    """

    test "`Absolute` functionality" do
      x = Variable.new(-2..2, name: "x")
      y = Variable.new(-2..2, name: "y")

      model = Model.new([x, y], [Absolute.new(x, y)])

      {:ok, res} = CPSolver.solve_sync(model)
      assert res.statistics.solution_count == 5
      assert check_solutions(res)

    end

    test "inconsistency" do
      x = Variable.new(0, name: "x")
      y = Variable.new(1, name: "y")

      model = Model.new([x, y], [Absolute.new(x, y)])
      {:ok, res} = CPSolver.solve_sync(model)
      assert res.status == :unsatisfiable
    end

    test "factory" do
      x = Variable.new(-2..2, name: "x")

      {abs_var, abs_constraint} = ConstraintFactory.absolute(x)

      assert Interface.min(abs_var) == 0
      assert Interface.max(abs_var) == 2

      model = Model.new([x], [abs_constraint])

      {:ok, res} = CPSolver.solve_sync(model)
      assert res.statistics.solution_count == 5
      assert check_solutions(res)
    end

    defp check_solutions(result) do
      Enum.all?(result.solutions, fn [x_val, y_val] -> y_val == abs(x_val) end)
    end
  end
end
