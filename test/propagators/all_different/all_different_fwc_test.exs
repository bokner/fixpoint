defmodule CPSolverTest.Propagator.AllDifferent.FWC do
  use ExUnit.Case

  describe "Propagator filtering" do
    alias CPSolver.ConstraintStore
    alias CPSolver.IntVariable, as: Variable
    alias CPSolver.Variable.Interface
    alias CPSolver.Propagator
    alias CPSolver.Propagator.AllDifferent.FWC
    import CPSolver.Test.Helpers

    test "unsatisfiable" do
      x = Enum.map([2, 1, 1, 3], fn val -> Variable.new(val) end)
      {:ok, x_vars, _store} = ConstraintStore.create_store(x)
      fwc_propagator = FWC.new(x_vars)
      assert :fail == Propagator.filter(fwc_propagator)
    end

    test "maintains the list of unfixed variables" do
      x =
        Enum.map([{"x1", 0..5}, {"x2", 1..4}, {"x3", 0..5}, {"x4", 4}, {"x5", 5}], fn {name, d} ->
          Variable.new(d, name: name)
        end)

      {:ok, x_vars, _store} = create_store(x)

      [x1_var, x2_var, x3_var, _x4_var, _x5_var] = x_vars

      ## Initial state
      ##
      fwc_propagator = FWC.new(x_vars)
      filtering_results = Propagator.filter(fwc_propagator)

      # IO.inspect(filtering_results)
      ## The values of fixed variables (namely, 4 and 5) have been removed from unfixed variables
      assert Enum.all?([x1_var, x2_var, x3_var], fn var -> Interface.max(var) == 3 end)

      ## Fixing one of the variables will remove the value it's fixed to from other variables
      :fixed = Interface.fix(x1_var, 3)

      ## Emulate changes that would come from the propagation process.
      ## x1 is at position 0 in the propagator arguments
      changes = %{0 => :fixed}

      fwc_propagator_step2 = Map.put(fwc_propagator, :state, filtering_results.state)
      _filtering_results2 = Propagator.filter(fwc_propagator_step2, changes: changes)
      # IO.inspect(filtering_results2)

      assert Interface.min(x2_var) == 1 && Interface.max(x2_var) == 2
      assert Interface.min(x3_var) == 0 && Interface.max(x3_var) == 2
    end

    test "cascading filtering" do
      ## x1 is fixed, so the filtering removes 1 from all other variables.
      ## This makes x2 fixed, which in turn triggers a removal of 2 from x3 to x5 etc.
      ## Eventually all variables become fixed, and this will take a single filtering call.
      ##
      x =
        Enum.map([{"x2", 1..2}, {"x1", 1}, {"x3", 1..3}, {"x4", 1..4}, {"x5", 1..5}], fn {name, d} ->
          Variable.new(d, name: name)
        end)

      {:ok, x_vars, _store} = create_store(x)

      fwc_propagator = FWC.new(x_vars)
      %{changes: changes} = Propagator.filter(fwc_propagator)

      ## x1 was already fixed; the filtering fixes the rest
      assert map_size(changes) == length(x_vars) - 1
      assert Enum.all?(Map.values(changes), fn change -> change == :fixed end)
      assert Enum.all?(x_vars, &Interface.fixed?/1)

      ## Consequent filtering does not result in more changes and/or failures
      assert Map.get(Propagator.filter(fwc_propagator), :changes) in [nil, %{}]
      assert Enum.all?(x_vars, &Interface.fixed?/1)
    end
  end
end
