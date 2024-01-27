defmodule CpSolverTest.Objective do
  use ExUnit.Case
  alias CPSolver.IntVariable, as: Variable
  alias CPSolver.Model
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

      assert %{changes: nil, active?: true, state: nil} ==
               Propagator.filter(min_propagator, store: store)

      ## Tighten the bound (this will set the bound to objective_variable.max() - 1)
      Objective.tighten(min_objective)

      assert Objective.get_bound(min_handle) == 9

      ## Propagation will result in :max_change, :fixed, or :fail for the objective variable, if the global bound changes
      assert %{
               changes: %{Interface.id(objective_variable) => :max_change},
               active?: true,
               state: nil
             } ==
               Propagator.filter(min_propagator)

      ## Propagation doesn't change a global bound
      assert Objective.get_bound(min_handle) == 9
      Objective.update_bound(min_handle, Interface.min(objective_variable))

      assert %{changes: %{Interface.id(objective_variable) => :fixed}, active?: true, state: nil} ==
               Propagator.filter(min_propagator)

      ## Tightening bound when the objective variable is fixed
      Objective.tighten(min_objective)

      assert {:fail, Interface.id(objective_variable)} == Propagator.filter(min_propagator)
    end
  end

  describe "Objectives in solutions" do
    alias CPSolver.Constraint.{LessOrEqual, Sum}
    alias CPSolver.Examples.Knapsack

    test "sanity test for minimization and maximization" do
      sum_bound = 1000
      x_bound = 100
      y_bound = 200
      x = Variable.new(1..x_bound, name: "x")
      y = Variable.new(1..y_bound, name: "y")
      z = Variable.new(1..sum_bound)

      variables = [x, y]
      constraints = [LessOrEqual.new(x, y), Sum.new(z, [x, y])]

      minimization_model =
        Model.new(
          variables,
          constraints,
          objective: Objective.minimize(z)
        )

      maximization_model =
        Model.new(
          variables,
          constraints,
          objective: Objective.maximize(z)
        )

      {:ok, min_res} = CPSolver.solve_sync(minimization_model)
      assert min_res.objective == 2
      assert List.last(min_res.solutions) == [1, 1, 2]

      {:ok, max_res} = CPSolver.solve_sync(maximization_model)

      assert max_res.objective == min(sum_bound, x_bound + y_bound)
      [x_val, y_val, sum_bound] = List.last(max_res.solutions)
      assert x_val + y_val == sum_bound
    end

    test "The best solution with respect to optimization criterion will be the last in the list" do
      ## We use a small knapsack instance that is known to emit 2 solutions
      model_instance = "data/knapsack/ks_4_0"
      ## Value maximization model
      value_knapsack_model = Knapsack.model(model_instance, :value_maximization)
      {:ok, value_res} = CPSolver.solve_sync(value_knapsack_model)
      total_value_idx = Enum.find_index(value_res.variables, fn name -> name == "total_value" end)
      assert List.last(value_res.solutions) |> Enum.at(total_value_idx) == value_res.objective

      ## Free space minimization model
      space_minimization_model =
        Knapsack.model(model_instance, :free_space_minimization)

      {:ok, space_res} = CPSolver.solve_sync(space_minimization_model)

      total_value_idx =
        Enum.find_index(space_res.variables, fn name -> name == "total_weight" end)

      ## Note: the solution contains variable values, but not the objective (view) values.
      ## Thus for the purpose of asserting that the fixed value for the objective variable
      ## corresponds to the objective value, we will map one onto another.
      assert List.last(space_res.solutions) |> Enum.at(total_value_idx) ==
               Interface.map(space_minimization_model.objective.variable, space_res.objective)
    end
  end
end
