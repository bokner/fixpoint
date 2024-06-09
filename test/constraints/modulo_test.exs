defmodule CPSolverTest.Constraint.Element do
  use ExUnit.Case, async: false

  describe "Modulo" do
    alias CPSolver.Constraint.Modulo
    alias CPSolver.IntVariable, as: Variable
    alias CPSolver.Model

    test "`modulo` functionality" do
      x = Variable.new(-3..3, name: "x")
      y = Variable.new(-2..2, name: "y")
      m = Variable.new(-10..10, name: "m")

      model = Model.new([x, y, m], [Modulo.new(m, x, y)])

      {:ok, res} = CPSolver.solve_sync(model)
      IO.inspect(res)

    end
  end
end
