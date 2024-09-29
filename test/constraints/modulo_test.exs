defmodule CPSolverTest.Constraint.Modulo do
  use ExUnit.Case, async: false

  describe "Modulo" do
    alias CPSolver.Constraint.Modulo
    alias CPSolver.IntVariable, as: Variable
    alias CPSolver.Variable.Interface
    alias CPSolver.Model
    alias CPSolver.Constraint.Factory, as: ConstraintFactory

    ~c"""
    MiniZinc model (for verification):

    var -2..2: x;
    var -2..2: y;
    var -100..100: m;
    constraint m = x mod y;

    """

    test "`modulo` functionality" do
      x = Variable.new(-2..2, name: "x")
      y = Variable.new(-2..2, name: "y")
      m = Variable.new(-100..100, name: "m")

      model = Model.new([x, y, m], [Modulo.new(m, x, y)])

      {:ok, res} = CPSolver.solve_sync(model)
      assert res.statistics.solution_count == 20
      assert check_solutions(res)
    end

    test "Factory.mod/2,3" do
      x = Variable.new(-100..100, name: "x")
      y = Variable.new(-7..7, name: "y")
      {mod_var, mod_constraint} = ConstraintFactory.mod(x, y)
      assert Interface.min(mod_var) == -6
      assert Interface.max(mod_var) == 6

      model = Model.new([x, y], [mod_constraint])
      {:ok, res} = CPSolver.solve_sync(model)
      ## Verification against MiniZinc count
      assert res.statistics.solution_count == 2814
      assert check_solutions(res)
    end

    defp check_solutions(result) do
      Enum.all?(result.solutions, fn [x_val, y_val, m_val] -> rem(x_val, y_val) == m_val end)
    end
  end
end
