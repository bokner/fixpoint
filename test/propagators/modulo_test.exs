defmodule CPSolverTest.Propagator.Modulo do
  use ExUnit.Case
  import CPSolver.Test.Helpers

  describe "Propagator filtering" do
    alias CPSolver.IntVariable, as: Variable
    alias CPSolver.Variable.Interface
    alias CPSolver.Propagator
    alias CPSolver.Propagator.Modulo

    test "filtering, unfixed domains" do
      ## Both vars are unfixed
      x = 1..10
      y = -5..5
      m = -10..10
      variables = Enum.map([m, x, y], fn d -> Variable.new(d) end)

      {:ok, [m_var, x_var, y_var] = bound_vars, _store} = create_store(variables)
      # before filtering
      assert Interface.contains?(y_var, 0)
      assert Interface.min(m_var) == -10

      p = Modulo.new(bound_vars)
      res = Propagator.filter(p)
      ## y has 0 removed
      refute Interface.contains?(y_var, 0)

      ## None is fixed
      refute Enum.any?(bound_vars, fn var -> Interface.fixed?(var) end)


    end

  end
end
