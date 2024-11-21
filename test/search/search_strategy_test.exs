defmodule CPSolverTest.Search.FirstFail do
  use ExUnit.Case

  alias CPSolver.IntVariable, as: Variable
  alias CPSolver.DefaultDomain, as: Domain
  alias CPSolver.Search
  alias CPSolver.Search.Partition
  describe "First-fail search strategy" do
    alias CPSolver.Search.VariableSelector, as: SearchStrategy


    import CPSolver.Test.Helpers

    test ":first_fail and :indomain_min" do
      v0_values = 0..0
      v1_values = 1..10
      # This domain (will be assigned to `v2` variable) is the smallest among unfixed
      v2_values = 0..5
      v3_values = 1..1
      v4_values = -5..5
      values = [v0_values, v1_values, v2_values, v3_values, v4_values]
      variables = Enum.map(values, fn d -> Variable.new(d) end)

      {:ok, bound_vars, _store} = create_store(variables)

      # first_fail chooses among unfixed variables
      selected_variable = SearchStrategy.select_variable(variables, nil, :first_fail)

      assert selected_variable.id in Enum.map([1, 2, 4], fn var_pos ->
               Enum.at(bound_vars, var_pos) |> Map.get(:id)
             end)

      # indomain_min splits domain of selected variable into min and the rest of the domain
      {:ok, [{min_value_partition, _equal_constraint}, {no_min_partition, _not_equal_constraint}]} =
        Partition.partition(selected_variable, :indomain_min)

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

      {:ok, _bound_vars, _store} = create_store(variables)

      assert catch_throw(Search.branch(variables, {:first_fail, :indomain_min})) ==
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

      {:ok, bound_vars, _store} = create_store(variables)

      [b_left, b_right] =
        branches = Search.branch(bound_vars, {:first_fail, :indomain_min})

      refute b_left == b_right
      ## Each branch has the same number of variables, as the original list of vars
      assert Enum.all?(branches, fn {branch, _constraint} ->
               length(branch) == length(variables)
             end)

      ## Left branch contains v2 variable fixed at 0
      assert Enum.at(b_left |> elem(0), 2)
             |> Map.get(:domain)
             |> then(fn domain -> Domain.size(domain) == 1 && Domain.min(domain) == 0 end)

      ## Right branch contains v2 variable with 0 removed
      refute Enum.at(b_right |> elem(0), 2) |> Map.get(:domain) |> Domain.contains?(0)
    end
  end

  describe "Misc strategies" do
    alias CPSolver.Search.VariableSelector.MaxRegret, as: MaxRegretSelector

    test "max_regret selector" do
      domains = [1..3, [2, 10, 11], [3, 12, 15], [6, 15]]

      variables =
        Enum.map(Enum.with_index(domains, 1), fn {d, idx} -> Variable.new(d, name: idx) end)

      [var1, var2] = MaxRegretSelector.select(variables, :ignore)
      ## Chooses variables with largest difference between 2 smallest values
      ## diff(1) = 1, diff(2) = 8, diff(3) = diff(4) = 9
      assert var1.name in [3, 4] && var2.name in [3, 4]
    end

    test "indomain_split" do
      var = Variable.new([1, 2, 3, 4, 5])
      {:ok, [p1, p2]} = Partition.partition(var, :indomain_split)
      p1_domain = elem(p1, 0)
      assert Domain.to_list(p1_domain) == MapSet.new([1, 2, 3])
      p2_domain = elem(p2, 0)
      assert Domain.to_list(p2_domain) == MapSet.new([4, 5])
    end
  end
end
