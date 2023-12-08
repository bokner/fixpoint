defmodule CPSolverTest.Propagator.NotEqual do
  use ExUnit.Case

  describe "Propagator filtering" do
    alias CPSolver.ConstraintStore
    alias CPSolver.IntVariable, as: Variable
    alias CPSolver.Propagator.Variable, as: PropagatorVariable
    alias CPSolver.Propagator.NotEqual

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

      {:ok, bound_vars, _store} = ConstraintStore.create_store(variables)
      assert :stable == reset_and_filter(bound_vars)
      refute PropagatorVariable.get_variable_ops()

      [x_var, y_var] = bound_vars
      ## Fix one of vars
      assert :fixed = Variable.fix(x_var, 5)
      assert :max_change == reset_and_filter(bound_vars)
      assert PropagatorVariable.get_variable_ops() == %{y_var.id => :max_change}

      ## The filtering should have removed '5' from y_var
      assert Variable.max(y_var) == 4
      assert Variable.min(y_var) == -5

      ## Fix second var and filter again
      assert :fixed == Variable.fix(y_var, 4)
      assert :no_change == reset_and_filter(bound_vars)
      refute PropagatorVariable.get_variable_ops()
      ## Make sure filtering doesn't fail on further calls
      refute Enum.any?(
               [x_var, y_var],
               fn var -> :fail == Variable.min(var) end
             )

      ## Consequent filtering does not trigger domain change events
      assert :no_change == reset_and_filter(bound_vars)
    end

    test "inconsistency" do
      x = 0..0
      y = 0..0
      [_x_var, y_var] = variables = Enum.map([x, y], fn d -> Variable.new(d) end)

      {:ok, bound_vars, _store} = ConstraintStore.create_store(variables, space: nil)
      assert catch_throw(NotEqual.filter(bound_vars)) == {:fail, y_var.id}
      assert PropagatorVariable.get_variable_ops() == nil
      ## One of variables (depending on filtering implementation) will fail
      assert Enum.any?(
               bound_vars,
               fn var -> :fail == Variable.fixed?(var) end
             )
    end

    test "offset" do
      x = 5..5
      y = -5..10
      variables = Enum.map([x, y], fn d -> Variable.new(d) end)
      {:ok, [x_var, y_var], _store} = ConstraintStore.create_store(variables)

      assert Variable.contains?(y_var, 0)
      # (x != y + 5)
      offset = 5
      NotEqual.filter(x_var, y_var, offset)
      refute Variable.contains?(y_var, 0)

      # (x != y - 5)
      offset = -5
      assert Variable.contains?(y_var, 10)
      NotEqual.filter(x_var, y_var, offset)
      refute Variable.contains?(y_var, 10)
    end

    defp reset_and_filter(args) do
      PropagatorVariable.reset_variable_ops()
      NotEqual.filter(args)
    end
  end
end
