defmodule CPSolverTest.Propagator.NotEqual do
  use ExUnit.Case

  import ExUnit.CaptureLog

  describe "Propagator filtering" do
    alias CPSolver.Store.Registry, as: Store
    alias CPSolver.IntVariable, as: Variable
    alias CPSolver.Propagator.NotEqual

    test "filtering, unfixed domains" do
      space = :top_space

      ## Both vars are unfixed
      x = 1..10
      y = -5..5
      variables = Enum.map([x, y], fn d -> Variable.new(d) end)

      {:ok, bound_vars} = Store.create(space, variables)
      assert :stable == NotEqual.filter(bound_vars)

      [x_var, y_var] = bound_vars
      ## Fix one of vars
      :ok = Store.update(space, x_var, :fix, [5])
      assert :ok == NotEqual.filter(bound_vars)
      ## The filtering should have removed '5' from y_var
      assert Store.get(space, y_var, :max) == 4
      assert Store.get(space, y_var, :min) == -5

      ## Fix second var and filter again
      :ok = Store.update(space, y_var, :fix, [4])
      assert :ok == NotEqual.filter(bound_vars)
      ## Make sure filtering doesn't fail on further calls
      refute Enum.any?(
               [x_var, y_var],
               fn var -> :fail == Store.get(space, var, :min) end
             )

      ## Consequent filtering does not trigger domain change events
      refute capture_log([level: :debug], fn ->
               NotEqual.filter(bound_vars)
               Process.sleep(10)
             end) =~ "Domain change"
    end

    test "inconsistency" do
      space = :top_space
      x = 0..0
      y = 0..0
      variables = Enum.map([x, y], fn d -> Variable.new(d) end)

      {:ok, bound_vars} = Store.create(space, variables)
      assert :ok == NotEqual.filter(bound_vars)

      ## One of variables (depending on filtering implementation) will fail
      assert Enum.any?(
               bound_vars,
               fn var -> :fail == Store.get(space, var, :fixed?) end
             )
    end
  end
end
