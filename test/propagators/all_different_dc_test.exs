defmodule CPSolverTest.Propagator.AllDifferent.DC do
  use ExUnit.Case

  describe "Propagator filtering" do
    alias CPSolver.ConstraintStore
    alias CPSolver.IntVariable, as: Variable
    alias CPSolver.Variable.Interface
    alias CPSolver.Propagator
    alias CPSolver.Propagator.AllDifferent.DC

    test "initial reduction" do
      domains = [1..2, 1, 2..6, 2..6]
      vars =
        Enum.map(domains, fn d -> Variable.new(d) end)

      {:ok, bound_vars, _store} = CPSolver.ConstraintStore.create_store(vars)
      dc_propagator = DC.new(bound_vars)
      %{changes: changes} = Propagator.filter(dc_propagator)

      x0 = Arrays.get(bound_vars, 0)
      x2 = Arrays.get(bound_vars, 2)
      x3 = Arrays.get(bound_vars, 3)
      ## Value 1 removed from x0
      assert Interface.min(x0) == 2
      ## Value 2 is removed from variables x2 and x3
      assert Interface.min(x2) == 3 && Interface.min(x3) == 3
      ## Changes: x0 is fixed, x2 and x3 chnge their minimum
      assert changes[x0.id] == :fixed
      assert changes[x2.id] == :min_change
      assert changes[x3.id] == :min_change
    end

    test "cascading filtering" do
      ## all variables become fixed, and this will take a single filtering call.
      ##
      x =
        Enum.map([{"x2", 1..2}, {"x1", 1}, {"x3", 1..3}, {"x4", 1..4}, {"x5", 1..5}], fn {name, d} ->
          Variable.new(d, name: name)
        end)

      {:ok, x_vars, _store} = ConstraintStore.create_store(x)

      dc_propagator = DC.new(x_vars)
      %{changes: changes} = Propagator.filter(dc_propagator)

      ## x1 was already fixed; the filtering fixes the rest
      assert map_size(changes) == Arrays.size(x_vars) - 1
      assert Enum.all?(Map.values(changes), fn change -> change == :fixed end)
      assert Enum.all?(x_vars, &Interface.fixed?/1)

      ## Consequent filtering does not result in more changes and/or failures
      ## TODO!
      #%{changes: nil} = Propagator.filter(dc_propagator)
      #assert Enum.all?(x_vars, &Interface.fixed?/1)
    end
  end
end
