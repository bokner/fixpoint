defmodule CPSolverTest.Search.FirstFail do
  use ExUnit.Case

  describe "First-fail search strategy" do
    alias CPSolver.Store.Registry, as: Store
    alias CPSolver.IntVariable, as: Variable
    alias CPSolver.DefaultDomain, as: Domain
    alias CPSolver.Search.Strategy, as: SearchStrategy
    alias CPSolver.Search.Strategy.FirstFail

    test "first_fail chooses unfixed variable with minimal domain size" do
      space = self()
      v0_values = 0..0
      v1_values = 1..10
      # This domain is the smallest among unfixed
      v2_values = 0..5
      v3_values = 1..1
      v4_values = -5..5
      values = [v0_values, v1_values, v2_values, v3_values, v4_values]
      variables = Enum.map(values, fn d -> Variable.new(d) end)

      {:ok, bound_vars} = Store.create(space, variables)
      selected_variable = FirstFail.select_variable(bound_vars)
      v2_var = Enum.at(bound_vars, 2)
      assert selected_variable == v2_var

      var_domain = Store.domain(space, selected_variable)
      min_val = Domain.min(var_domain)

      assert FirstFail.partition(var_domain) ==
               [0, Domain.new(List.delete(Enum.to_list(v2_values), 0))]
    end

    test "first_fail fails if no unfixed variables" do
      space = self()
      v0_values = 0..0
      v1_values = 1..1
      v2_values = -2..-2
      v3_values = 1..1
      v4_values = 5..5
      values = [v0_values, v1_values, v2_values, v3_values, v4_values]
      variables = Enum.map(values, fn d -> Variable.new(d) end)

      {:ok, _bound_vars} = Store.create(space, variables)

      assert catch_throw(FirstFail.select_variable(variables)) ==
               SearchStrategy.no_variable_choice_exception()
    end
  end
end
