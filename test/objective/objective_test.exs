defmodule CpSolverTest.Objective do
  use ExUnit.Case
  alias CPSolver.IntVariable, as: Variable
  alias CPSolver.Objective
  alias CPSolver.Propagator
  alias CPSolver.ConstraintStore
  alias CPSolver.Variable.Interface

  describe "Objective API" do
    test "low-level operations" do
      handle = Objective.init_bound_handle()
      Objective.update_bound(handle, 100)
      assert 100 == Objective.get_bound(handle)
      ## Updates the bound with the lower value
      Objective.update_bound(handle, 10)
      assert 10 == Objective.get_bound(handle)
      ## Doesn't update the bound with the higher value
      Objective.update_bound(handle, 100)
      assert 10 == Objective.get_bound(handle)
    end

    test "concurrent updates to the bound result in setting the lowest bound value" do
      handle = Objective.init_bound_handle()
      refute 1 == Objective.get_bound(handle)
      num_updates = 1000
      bounds = Enum.shuffle(1..num_updates)

      results =
        Task.async_stream(bounds, fn b ->
          Objective.update_bound(handle, b)
        end)
        |> Enum.to_list()

      assert num_updates == length(results)
      assert 1 == Objective.get_bound(handle)
    end

    test "Propagation and tightening" do
      {:ok, [objective_variable] = _bound_vars, store} =
        ConstraintStore.create_store([Variable.new(1..10)])

      min_objective =
        %{propagator: min_propagator, bound_handle: min_handle} =
        Objective.minimize(objective_variable)

      assert :stable == Propagator.filter(min_propagator, store: store)
      ## Tighten the bound (this will set the bound to objective_variable.max() - 1)
      Objective.tighten(min_objective)

      assert Objective.get_bound(min_handle) == 9

      ## Propagation will result in :max_change, :fixed, or :fail for the objective variable, if the global bound changes
      assert {:changed, %{Interface.id(objective_variable) => :max_change}} ==
               Propagator.filter(min_propagator)

      ## Propagation doesn't change a global bound
      assert Objective.get_bound(min_handle) == 9
      Objective.update_bound(min_handle, Interface.min(objective_variable))

      assert {:changed, %{Interface.id(objective_variable) => :fixed}} ==
               Propagator.filter(min_propagator)

      ## Tightening bound when the objective variable is fixed
      Objective.tighten(min_objective)

      assert {:fail, Interface.id(objective_variable)} == Propagator.filter(min_propagator)
    end
  end
end
