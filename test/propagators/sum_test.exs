defmodule CPSolverTest.Propagator.Sum do
  use ExUnit.Case

  describe "Propagator filtering" do
    alias CPSolver.ConstraintStore
    alias CPSolver.IntVariable, as: Variable
    alias CPSolver.Propagator
    alias CPSolver.Propagator.Sum

    test "Test 1" do
      y = Variable.new(-100..100, name: "y")

      x =
        Enum.map([{"x1", 0..5}, {"x2", 1..5}, {"x3", 0..5}], fn {name, d} ->
          Variable.new(d, name: name)
        end)

      {:ok, [y_var | x_vars] = bound_vars, _store} = ConstraintStore.create_store([y | x])

      Sum.filter([x_vars, y])

      assert 1 = Variable.min(y_var)
      assert 15 = Variable.max(y_var)
    end
  end
end
