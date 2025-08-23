defmodule CPSolverTest.Constraint.AllDifferent.Utils do
  use ExUnit.Case, async: false
  alias CPSolver.Propagator.AllDifferent.Utils, as: AllDiffUtils

  describe "Forward checking" do
    alias CPSolver.IntVariable, as: Variable
    test "cascading" do
      domains = [1, 1..2, 1..3, 1..4, 1..5]
      vars = Enum.map(Enum.shuffle(domains), fn d -> Variable.new(d) end)
      {unfixed_indices, fixed_values} = AllDiffUtils.forward_checking(vars)

      assert MapSet.size(fixed_values) == length(vars)
      ## Everything is fixed
      assert Enum.empty?(unfixed_indices)
      assert Enum.all?(vars, fn var -> Variable.fixed?(var) end)
      ## AllDifferent check
      assert MapSet.new(vars, fn var -> Variable.min(var) end) |> MapSet.size() == length(vars)
    end

    test "pigeonhole" do
      domains = [1..2, 1..2, 1..2]
      vars = Enum.map(Enum.shuffle(domains), fn d -> Variable.new(d) end)
      {unfixed_indices, fixed_values} = AllDiffUtils.forward_checking(vars)
      ## FWC does not reduce if no fixed variables
      assert MapSet.size(unfixed_indices) == length(vars)
      assert Enum.empty?(fixed_values)
      ## Trigger reduction by fixing one of the variables
      Variable.fix(Enum.random(vars), Enum.random(1..2))
      assert catch_throw(:fail = AllDiffUtils.forward_checking(vars))
    end

    test "reuse" do
      # An example from Zhang
      domains = [1, 1..2, 1..4, [1, 2, 4, 5]]
      vars = Enum.map(domains, fn d -> Variable.new(d) end)
      {unfixed_indices, fixed_values} = AllDiffUtils.forward_checking(vars)
      ## First 2 variables fixed with values 1 and 2
      assert unfixed_indices == MapSet.new([2, 3])
      assert fixed_values == MapSet.new([1, 2])
      ## Run FWC again with the data from previous run - no effect
      assert {unfixed_indices, fixed_values} == AllDiffUtils.forward_checking(vars, unfixed_indices, fixed_values)
      ## Fix and run FWC again with previous results
      ##
      ## domain(var3) = [3,4]; domain(var4) = [4,5]
      ## Fix shared value (4) for any of the unfixed variables
      Variable.fix(Enum.at(vars, Enum.random([2,3])), 4)
      {unfixed_indices2, _fixed_values2} = AllDiffUtils.forward_checking(vars, unfixed_indices, fixed_values)
      ## Everything is fixed
      assert Enum.empty?(unfixed_indices2)
      assert Enum.all?(vars, fn var -> Variable.fixed?(var) end)
    end
  end
end
