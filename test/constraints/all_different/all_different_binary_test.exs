defmodule CPSolverTest.Constraint.AllDifferent do
  use ExUnit.Case, async: false

  describe "AllDifferent" do
    alias CPSolver.Propagator.NotEqual, as: PropagatorNotEqual
    alias CPSolver.Constraint.AllDifferent.Binary, as: AllDifferent
    alias CPSolver.IntVariable
    alias CPSolver.Constraint
    alias CPSolver.Model

    test "propagators" do
      domain = 1..3
      variables = Enum.map(1..3, fn i -> IntVariable.new(domain, name: "x#{i}") end)

      assert variables
             |> AllDifferent.propagators()
             |> Enum.map(fn %{mod: PropagatorNotEqual, args: [x, y, _]} ->
               "#{x.name} != #{y.name}"
             end)
             |> Enum.sort() ==
               ["x1 != x2", "x1 != x3", "x2 != x3"]
    end

    test "produces all possible permutations" do
      var_nums = 4
      domain = 1..var_nums
      variables = Enum.map(domain, fn _ -> IntVariable.new(domain) end)

      permutations = Permutation.permute!(Enum.to_list(domain))

      model = Model.new(variables, [Constraint.new(AllDifferent, variables)])

      {:ok, result} = CPSolver.solve(model)

      assert result.statistics.solution_count == MapSet.size(permutations)

      assert result.solutions |> MapSet.new() == permutations
    end
  end
end
