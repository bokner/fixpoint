defmodule CPSolverTest.Propagator do
  use ExUnit.Case

  describe "Propagator filtering" do
    alias CPSolver.Store.Registry, as: Store
    alias CPSolver.IntVariable, as: Variable

    test "NotEqual filtering" do
      alias CPSolver.Propagator.NotEqual

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
      ## Make sure filtering didn't fail
      assert Enum.all?([x_var, y_var], fn var -> Store.get(space, var, :fixed?) end)
    end
  end
end
