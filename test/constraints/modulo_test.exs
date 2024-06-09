defmodule CPSolverTest.Constraint.Element do
  use ExUnit.Case, async: false

  describe "Modulo" do
    alias CPSolver.Constraint.Modulo
    alias CPSolver.IntVariable, as: Variable
    alias CPSolver.Model

    ~c"""
    MiniZinc model (for verification):

    var -2..2: x;
    var -2..2: y;
    var -300..300: m;
    constraint m = x mod y;

    """

    test "`modulo` functionality" do
      x = Variable.new(-2..2, name: "x")
      y = Variable.new(-2..2, name: "y")
      m = Variable.new(-100..100, name: "m")

      model = Model.new([x, y, m], [Modulo.new(m, x, y)])

      {:ok, res} = CPSolver.solve_sync(model)
      assert res.statistics.solution_count == 20
      assert Enum.all?(res.solutions, fn [x_val, y_val, m_val] -> rem(x_val, y_val) == m_val end)
    end
  end
end
