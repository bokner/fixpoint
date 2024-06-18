defmodule CPSolverTest.Propagator.Absolute do
  use ExUnit.Case
  import CPSolver.Test.Helpers

  describe "Propagator filtering" do
    alias CPSolver.IntVariable, as: Variable
    alias CPSolver.Variable.Interface
    alias CPSolver.Propagator
    alias CPSolver.Propagator.Absolute

    test "filtering, initial call" do
      x = -1..10
      y = -5..5
      variables = Enum.map([x, y], fn d -> Variable.new(d) end)

      {:ok, [x_var, y_var] = bound_vars, _store} = create_store(variables)

      p = Absolute.new(bound_vars)
      _res = Propagator.filter(p)
      ## y has negative values removed
      assert Interface.min(y_var) >= 0
      ## min(y) = min(|x\)
      assert Interface.min(y_var) == 0
      assert Interface.max(y_var) == 5
      ## max(y) is now min(max(|x|), max(y) (i.e. din't change in this case)
      assert Interface.max(y_var) == Enum.max(y)
      ## domain of x is adjusted to domain of y
      assert Interface.min(x_var) == -1
      assert Interface.max(x_var) == 5
    end

    test "inconsistency, if domains y and |x| do not intersect" do
      x = 1..10
      y = 11..20
      variables = Enum.map([x, y], fn d -> Variable.new(d) end)

      {:ok, bound_vars, _store} = create_store(variables)
      p = Absolute.new(bound_vars)

      assert :fail = Propagator.filter(p)
    end
  end
end
