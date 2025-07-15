defmodule CPSolverTest.Constraint.AllDifferent.FWC do
  use ExUnit.Case, async: false

  describe "AllDifferentFWC" do
    alias CPSolver.Constraint.AllDifferent.FWC, as: AllDifferentFWC
    alias CPSolver.IntVariable
    alias CPSolver.Constraint
    alias CPSolver.Model
    import CPSolver.Variable.View.Factory

    test "all fixed" do
      variables = Enum.map(1..5, fn i -> IntVariable.new(i) end)
      model = Model.new(variables, [Constraint.new(AllDifferentFWC, variables)])
      {:ok, result} = CPSolver.solve(model)

      assert hd(result.solutions) == [1, 2, 3, 4, 5]
      assert result.statistics.solution_count == 1
    end

    test "produces all possible permutations" do
      var_nums = 4
      domain = 1..var_nums
      variables = Enum.map(domain, fn _ -> IntVariable.new(domain) end)

      permutations = Permutation.permute!(Enum.to_list(domain))

      model = Model.new(variables, [Constraint.new(AllDifferentFWC, variables)])

      {:ok, result} = CPSolver.solve(model)

      assert result.statistics.solution_count == MapSet.size(permutations)

      assert result.solutions |> MapSet.new() == permutations
    end

    test "unsatisfiable (duplicates)" do
      variables = Enum.map(1..3, fn _ -> IntVariable.new(1) end)
      assert catch_throw({:fail, _} = Model.new(variables, [Constraint.new(AllDifferentFWC, variables)]))
    end

    test "unsatisfiable(pigeonhole)" do
      variables = Enum.map(1..4, fn _ -> IntVariable.new(1..3) end)
      model = Model.new(variables, [Constraint.new(AllDifferentFWC, variables)])

      {:ok, result} = CPSolver.solve(model)

      assert result.status == :unsatisfiable
    end

    test "views in variable list" do
      n = 3
      variables = Enum.map(1..n, fn i -> IntVariable.new(1..n, name: "row#{i}") end)

      diagonal_down =
        Enum.map(Enum.with_index(variables, 1), fn {var, idx} -> linear(var, 1, -idx) end)

      diagonal_up =
        Enum.map(Enum.with_index(variables, 1), fn {var, idx} -> linear(var, 1, idx) end)

      model =
        Model.new(
          variables,
          [
            Constraint.new(AllDifferentFWC, diagonal_down),
            Constraint.new(AllDifferentFWC, diagonal_up),
            Constraint.new(AllDifferentFWC, variables)
          ]
        )

      {:ok, res} = CPSolver.solve(model)

      assert res.status == :unsatisfiable
    end
  end
end
