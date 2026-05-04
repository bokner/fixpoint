defmodule CPSolverTest.Search.Brancher do
  use ExUnit.Case

  alias CPSolver.IntVariable, as: Variable
  alias CPSolver.Variable.Interface
  alias CPSolver.DefaultDomain, as: Domain
  alias CPSolver.Search
  alias CPSolver.Search.Partition

  alias CPSolver.Utils.Vector

  describe "First-fail search strategy" do
    alias CPSolver.Search.VariableSelector, as: SearchStrategy

    test ":first_fail and :indomain_min" do
      v0_values = 0..0
      v1_values = 1..10
      # This domain (will be assigned to `v2` variable) is the smallest among unfixed
      v2_values = 0..5
      v3_values = 1..1
      v4_values = -5..5
      values = [v0_values, v1_values, v2_values, v3_values, v4_values]
      variables = Enum.map(values, fn d -> Variable.new(d) end)

      # first_fail chooses among unfixed variables
      selected_variable = SearchStrategy.select_variable(variables, nil, :first_fail)

      assert selected_variable.id in Enum.map([1, 2, 4], fn var_pos ->
               Enum.at(variables, var_pos) |> Map.get(:id)
             end)

      # indomain_min splits domain of selected variable into min and the rest of the domain
      {:ok, [fixed_value_partition, _removed_value_partition]} =
        Partition.partition(selected_variable, :indomain_min)

      ## Apply the 'partition' function
      fixed_value_fun = Map.get(fixed_value_partition, selected_variable.id)

      refute Interface.fixed?(selected_variable)

      fixed_value_fun.(selected_variable)

      assert Interface.fixed?(selected_variable)
    end

    test "first_fail fails if no unfixed variables" do
      v0_values = 0..0
      v1_values = 1..1
      v2_values = -2..-2
      v3_values = 1..1
      v4_values = 5..5
      values = [v0_values, v1_values, v2_values, v3_values, v4_values]
      variables = Enum.map(values, fn d -> Variable.new(d) end)

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

      [b_left, b_right] =
        branches =
        Search.branch(variables, {:first_fail, :indomain_min})
        |> Enum.map(fn partition_fun -> partition_fun.(variables, %{}) end)

      refute b_left == b_right
      ## Each branch has the same number of variables, as the original list of vars
      assert Enum.all?(branches, fn %{variable_copies: branch_variables} ->
               Vector.size(branch_variables) == length(variables)
             end)

      ## Left branch contains v2 variable fixed at 0
      assert Vector.at(b_left |> Map.get(:variable_copies), 2)
             |> Map.get(:domain)
             |> then(fn domain -> Domain.size(domain) == 1 && Domain.min(domain) == 0 end)

      ## Right branch contains v2 variable with 0 removed
      refute Vector.at(b_right |> Map.get(:variable_copies), 2) |> Map.get(:domain) |> Domain.contains?(0)
    end
  end

  describe "Misc strategies" do
    alias CPSolver.Search.VariableSelector.MaxRegret, as: MaxRegretSelector

    test "max_regret selector" do
      domains = [1..3, [2, 10, 11], [3, 12, 15], [6, 15]]

      variables =
        Enum.map(Enum.with_index(domains, 1), fn {d, idx} -> Variable.new(d, name: idx) end)

      [var1, var2] = MaxRegretSelector.select(variables, :ignore, :ignore)
      ## Chooses variables with largest difference between 2 smallest values
      ## diff(1) = 1, diff(2) = 8, diff(3) = diff(4) = 9
      assert var1.name in [3, 4] && var2.name in [3, 4]
    end

    test "indomain_split" do
      domain = [1, 2, 3, 4, 5]
      {part1, part2} = Enum.split(domain, div(length(domain), 2))
      variable = Variable.new(domain)
      {:ok, [p1, p2]} = Partition.partition(variable, :indomain_split)

      ## Apply the 'left-side partition' function
      ls_partition_fun = Map.get(p1, variable.id)

      variable_copy = Variable.new(domain)

      ls_partition_fun.(variable_copy)

      assert CPSolver.Utils.domain_values(variable_copy) == MapSet.new(part1)

      ## Apply the 'right-side partition' function
      rs_partition_fun = Map.get(p2, variable.id)

      variable_copy = Variable.new(domain)

      rs_partition_fun.(variable_copy)

      assert CPSolver.Utils.domain_values(variable_copy) == MapSet.new(part2)
    end
  end
end
