defmodule CpSolverTest.Objective do
  use ExUnit.Case
  alias CPSolver.IntVariable
  alias CPSolver.Variable
  alias CPSolver.Variable.View
  alias CPSolver.Solution.Objective
  alias CPSolver.ConstraintStore

  describe "Objective API" do
    test "basic operations" do
      {:ok, [objective_variable] = _bound_vars, _store} =
        ConstraintStore.create_store([IntVariable.new(1..10)])

      min_objective = Objective.minimize(objective_variable)
      max_objective = Objective.maximize(objective_variable)

      assert is_struct(min_objective.variable, Variable)
      assert is_struct(max_objective.variable, View)

      ## At initialization, objective bound is the max of objective variable
      assert Objective.get_bound(min_objective) == 10
      assert Objective.get_bound(max_objective) == -1
    end

    test "low-level operations" do
      handle = Objective.init_bound_handle()
      Objective.update_bound(handle, 10)
      assert 10 == Objective.get_bound(handle)
      ## Doesn't update the bound with the higher value
      Objective.update_bound(handle, 100)
      assert 10 == Objective.get_bound(handle)
      ## Updates the bound with the lower value
      Objective.update_bound(handle, 9)
      assert 9 == Objective.get_bound(handle)
    end

    test "concurrent updates end up with setting the lowest bound value" do
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
      ## The sequence of bound values is non-increasing
      bound_sequence = Enum.map(results, fn {:ok, bound} -> bound end)
      assert bound_sequence == Enum.sort(bound_sequence, :desc)
    end
  end
end
