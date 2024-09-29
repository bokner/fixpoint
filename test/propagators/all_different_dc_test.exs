defmodule CPSolverTest.Propagator.AllDifferent.DC do
  use ExUnit.Case

  describe "Propagator filtering" do
    alias CPSolver.IntVariable, as: Variable
    alias CPSolver.Propagator.AllDifferent.DC

    test "cascading filtering" do
      ## x1 is fixed, so the filtering removes 1 from all other variables.
      ## This makes x2 fixed, which in turn triggers a removal of 2 from x3 to x5 etc.
      ## Eventually all variables become fixed, and this will take a single filtering call.
      ##

      # x =
      #   Enum.map([{"x2", 1..2}, {"x1", 1}, {"x3", 1..3}, {"x4", 1..4}, {"x5", 1..5}], fn {name, d} ->
      #     Variable.new(d, name: name)
      #   end)

      # {:ok, x_vars, _store} = ConstraintStore.create_store(x)

      # fwc_propagator = FWC.new(x_vars)
      # %{changes: changes} = Propagator.filter(fwc_propagator)

      # ## x1 was already fixed; the filtering fixes the rest
      # assert map_size(changes) == length(x_vars) - 1
      # assert Enum.all?(Map.values(changes), fn change -> change == :fixed end)
      # assert Enum.all?(x_vars, &Interface.fixed?/1)

      # ## Consequent filtering does not result in more changes and/or failures
      # %{changes: nil} = Propagator.filter(fwc_propagator)
      # assert Enum.all?(x_vars, &Interface.fixed?/1)
    end
  end
end
