defmodule CPSolverTest.Search.FirstFail do
  use ExUnit.Case

  describe "First-fail search strategy" do
    alias CPSolver.ConstraintStore
    alias CPSolver.IntVariable, as: Variable
    alias CPSolver.DefaultDomain, as: Domain
    alias CPSolver.Search.Strategy, as: SearchStrategy

    test ":first_fail and :indomain_min" do
      v0_values = 0..0
      v1_values = 1..10
      # This domain is the smallest among unfixed
      v2_values = 0..5
      v3_values = 1..1
      v4_values = -5..5
      values = [v0_values, v1_values, v2_values, v3_values, v4_values]
      variables = Enum.map(values, fn d -> Variable.new(d) end)

      {:ok, bound_vars, _store} = ConstraintStore.create_store(variables)

      # first_fail chooses unfixed variable
      selected_variable = SearchStrategy.select_variable(bound_vars, :first_fail)
      v2_var = Enum.at(bound_vars, 2)
      assert selected_variable.id == v2_var.id

      # indomain_min splits domain of selected variable into min and the rest of the domain
      {:ok, [{min_value_partition, _equal_constraint}, {no_min_partition, _not_equal_constraint}]} =
        SearchStrategy.partition(selected_variable, :indomain_min)

      min_value = Domain.min(min_value_partition)

      assert Domain.to_list(no_min_partition) |> Enum.sort() ==
               List.delete(Enum.to_list(v2_values), min_value) |> Enum.sort()
    end

    test "first_fail fails if no unfixed variables" do
      v0_values = 0..0
      v1_values = 1..1
      v2_values = -2..-2
      v3_values = 1..1
      v4_values = 5..5
      values = [v0_values, v1_values, v2_values, v3_values, v4_values]
      variables = Enum.map(values, fn d -> Variable.new(d) end)

      {:ok, _bound_vars, _store} = ConstraintStore.create_store(variables)

      assert catch_throw(SearchStrategy.select_variable(variables, :first_fail)) ==
               SearchStrategy.all_vars_fixed_exception()
    end

    test "branch creation" do
      v0_values = 0..0
      v1_values = 1..10
      # This domain is the smallest among unfixed
      v2_values = 0..5
      v3_values = 1..1
      v4_values = -5..5
      values = [v0_values, v1_values, v2_values, v3_values, v4_values]
      variables = Enum.map(values, fn d -> Variable.new(d) end)

      {:ok, bound_vars, _store} = ConstraintStore.create_store(variables)

      [b_left, b_right] =
        branches = SearchStrategy.branch(bound_vars, {:first_fail, :indomain_min})

      refute b_left == b_right
      ## Each branch has the same number of variables, as the original list of vars
      assert Enum.all?(branches, fn {branch, _constraint} -> length(branch) == length(variables) end)
      ## Left branch contains v2 variable fixed at 0
      assert Enum.at(b_left |> elem(0), 2)
             |> Map.get(:domain)
             |> then(fn domain -> Domain.size(domain) == 1 && Domain.min(domain) == 0 end)

      ## Right branch contains v2 variable with 0 removed
      refute Enum.at(b_right |> elem(0), 2) |> Map.get(:domain) |> Domain.contains?(0)
    end
  end
end
