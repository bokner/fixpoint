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
  end
end
