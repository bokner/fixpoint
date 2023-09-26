defmodule CPSolverTest.Search.FirstFail do
  use ExUnit.Case

  describe "First-fail search strategy" do
    alias CPSolver.Store.Registry, as: Store
    alias CPSolver.ConstraintStore
    alias CPSolver.IntVariable, as: Variable
    alias CPSolver.DefaultDomain, as: Domain
    alias CPSolver.Search.Strategy, as: SearchStrategy
    alias CPSolver.Search.Strategy.FirstFail

    test "first_fail chooses unfixed variable with minimal domain size" do
      store = :dummy
      v0_values = 0..0
      v1_values = 1..10
      # This domain is the smallest among unfixed
      v2_values = 0..5
      v3_values = 1..1
      v4_values = -5..5
      values = [v0_values, v1_values, v2_values, v3_values, v4_values]
      variables = Enum.map(values, fn d -> Variable.new(d) end)

      {:ok, bound_vars, _store} = ConstraintStore.create_store(Store, variables)
      {localized_vars, _} = CPSolver.Utils.localize_variables(bound_vars)
      {:ok, selected_variable} = FirstFail.select_variable(localized_vars)
      v2_var = Enum.at(bound_vars, 2)
      assert selected_variable.id == v2_var.id

      var_domain = Store.domain(store, selected_variable)
      min_val = Domain.min(var_domain)

      assert FirstFail.partition(var_domain) ==
               {:ok, [min_val, Domain.new(List.delete(Enum.to_list(v2_values), 0))]}
    end

    test "first_fail fails if no unfixed variables" do
      v0_values = 0..0
      v1_values = 1..1
      v2_values = -2..-2
      v3_values = 1..1
      v4_values = 5..5
      values = [v0_values, v1_values, v2_values, v3_values, v4_values]
      variables = Enum.map(values, fn d -> Variable.new(d) end)

      {:ok, _bound_vars, _store} = ConstraintStore.create_store(Store, variables)

      assert FirstFail.select_variable(variables) ==
               {:error, SearchStrategy.all_vars_fixed_exception()}
    end
  end
end
