defmodule CPSolverTest.Constraint.AllDifferent.Utils do
  use ExUnit.Case, async: false
  alias CPSolver.Propagator.AllDifferent.Utils, as: AllDiffUtils

  describe "Forward checking" do
    alias CPSolver.IntVariable, as: Variable
    test "cascading" do
      domains = [1, 1..2, 1..3, 1..4, 1..5]
      vars = Enum.map(Enum.shuffle(domains), fn d -> Variable.new(d) end)
      {unfixed_indices, fixed_values} = AllDiffUtils.forward_checking(vars)
      assert Enum.empty?(unfixed_indices)
      ## The number of fixed values equals the number of variables
      assert MapSet.size(fixed_values) == length(vars)
    end
  end
end
