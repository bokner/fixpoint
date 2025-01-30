defmodule CPSolverTest.Propagator.NotEqual do
  use ExUnit.Case

  describe "Propagator filtering" do
    alias CPSolver.IntVariable, as: Variable
    alias CPSolver.Propagator.Variable, as: PropagatorVariable
    alias CPSolver.Propagator
    alias CPSolver.Propagator.NotEqual
    import CPSolver.Test.Helpers

    test "propagation events" do
      x = 1..10
      y = -5..5
      variables = Enum.map([x, y], fn d -> Variable.new(d) end)
      assert Enum.all?(NotEqual.variables(variables), fn v -> v.propagate_on == [:fixed] end)
    end

    test "filtering, unfixed domains" do
      ## Both vars are unfixed
      x = 1..10
      y = -5..5
      variables = Enum.map([x, y], fn d -> Variable.new(d) end)

      {:ok, bound_vars, _store} = create_store(variables)
      assert %{changes: %{}} = reset_and_filter(bound_vars)
      refute PropagatorVariable.get_variable_ops()

      [x_var, y_var] = bound_vars
      ## Fix one of vars
      assert :fixed = Variable.fix(x_var, 5)
      assert %{active?: false} = reset_and_filter(bound_vars)

      ## The filtering should have removed '5' from y_var
      assert Variable.max(y_var) == 4
      assert Variable.min(y_var) == -5

      ## Fix second var and filter again
      assert :fixed == Variable.fix(y_var, 4)
      assert %{active?: false} = reset_and_filter(bound_vars)
      ## Make sure filtering doesn't fail on further calls
      refute Enum.any?(
               [x_var, y_var],
               fn var -> :fail == Variable.min(var) end
             )

      ## Consequent filtering does not trigger domain change events
      assert %{active?: false} = reset_and_filter(bound_vars)
    end

    test "inconsistency" do
      x = 0..0
      y = 0..0
      variables = Enum.map([x, y], fn d -> Variable.new(d) end)

      {:ok, bound_vars, _store} = create_store(variables)
      assert Propagator.filter(NotEqual.new(bound_vars)) == :fail
      assert PropagatorVariable.get_variable_ops() == nil
    end

    test "offset" do
      x = 5..5
      y = -5..10
      variables = Enum.map([x, y], fn d -> Variable.new(d) end)
      {:ok, bound_vars, _store} = create_store(variables)
      [x_var, y_var] = bound_vars
      assert Variable.contains?(y_var, 0)
      # (x != y + 5)
      offset = 5
      Propagator.filter(NotEqual.new([x_var, y_var, offset]))
      refute Variable.contains?(y_var, 0)

      # (x != y - 5)
      offset = -5
      assert Variable.contains?(y_var, 10)
      Propagator.filter(NotEqual.new([x_var, y_var, offset]))
      refute Variable.contains?(y_var, 10)
    end

    defp reset_and_filter(args) do
      PropagatorVariable.reset_variable_ops()
      Propagator.filter(NotEqual.new(args))
    end
  end
end
