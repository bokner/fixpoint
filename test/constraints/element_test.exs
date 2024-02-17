defmodule CPSolverTest.Constraint.Element do
  use ExUnit.Case, async: false

  describe "AllDifferentFWC" do
    alias CPSolver.Constraint.Element
    alias CPSolver.IntVariable, as: Variable
    alias CPSolver.Model

    test "`element` functionality" do
      y = Variable.new(-3..10)
      z = Variable.new(-20..40)
      t = [9, 8, 7, 5, 6]

      model = Model.new([y, z], [Element.new(t, y, z)])

      {:ok, solver} = CPSolver.solve(model)

      Process.sleep(100)
      assert CPSolver.statistics(solver).solution_count == 5

      assert Enum.all?(CPSolver.solutions(solver), fn [y_value, z_value, _] ->
               Enum.at(t, y_value) == z_value
             end)
    end
  end
end
