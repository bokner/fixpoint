defmodule CPSolverTest.Propagator.AllDifferent.FWC do
  use ExUnit.Case

  describe "Propagator filtering" do
    alias CPSolver.ConstraintStore
    alias CPSolver.IntVariable, as: Variable
    alias CPSolver.Variable.Interface
    alias CPSolver.Propagator
    alias CPSolver.Propagator.AllDifferent.FWC

    test "maintains the list of unfixed variables and the list of fixed values" do
      x =
        Enum.map([{"x1", 0..5}, {"x2", 1..4}, {"x3", 0..5}, {"x4", 4}, {"x5", 5}], fn {name, d} ->
          Variable.new(d, name: name)
        end)

      {:ok, x_vars, _store} = ConstraintStore.create_store(x)

      [x1_var, x2_var, x3_var, _x4_var, _x5_var] = x_vars

      ## Initial state
      ##
      fwc_propagator = FWC.new(x_vars)
      filtering_results = Propagator.filter(fwc_propagator)

      %{unfixed_vars: unfixed_vars} = filtering_results.state
      ## x1, x2 and x3 should be in unfixed_vars list
      assert map_size(unfixed_vars) == 3

      assert Enum.all?([x1_var, x2_var, x3_var], fn var ->
               Map.has_key?(unfixed_vars, Interface.id(var))
             end)

      ## The values of fixed variables (namely, 4 and 5) have been removed from unfixed variables
      assert Enum.all?([x1_var, x2_var, x3_var], fn var -> Interface.max(var) == 3 end)

      ## Fixing one of the variables will remove the value it's fixed to from other variables
      :fixed = Interface.fix(x1_var, 3)

      fwc_propagator_step2 = Map.put(fwc_propagator, :state, filtering_results.state)
      filtering_results2 = Propagator.filter(fwc_propagator_step2)

      %{unfixed_vars: updated_unfixed_vars} = filtering_results2.state

      ## x1 had been fixed, and so is now removed from unfixed vars
      assert map_size(updated_unfixed_vars) == 2

      assert Interface.min(x2_var) == 1 && Interface.max(x2_var) == 2
      assert Interface.min(x3_var) == 0 && Interface.max(x3_var) == 2

      ## Removing 2 from x3 will force removal of 2 from x2;
      ## This, in turn, will make x2 fixed to 1. This would trigger a removal of 1 from x3.
      ## Both varibales should now be fixed.
      Interface.remove(x3_var, 2)

      fwc_propagator_step3 = Map.put(fwc_propagator, :state, filtering_results2.state)
      _filtering_results3 = Propagator.filter(fwc_propagator_step3)

      assert Interface.fixed?(x2_var) && Interface.fixed?(x3_var)
      assert Interface.min(x3_var) == 0 && Interface.min(x3_var) == 1

      # ## The filtering will now remove fixed value for x1 from remaining unfixed variables
      # Propagator.filter(updated_fwc_propagator)

      # refute Enum.any?([x2_var, x3_var], fn var ->
      #          Interface.contains?(var, Interface.min(x1_var))
      #        end)

      # ## At this point, x2 has 2 values
      # assert Interface.min(x2_var) == 2
      # assert Interface.max(x2_var) == 3

      # ## If the variable was fixed outside the propagator
      # ## (as in this case, x3 was fixed to max(x2)),
      # ## the filtering should detect and act on it without explicit call to update/2
      # :fixed = Interface.fix(x3_var, Interface.max(x2_var))

      # Propagator.filter(updated_fwc_propagator)
      # assert Interface.fixed?(x2_var) && Interface.min(x2_var) == 2
    end
  end
end
