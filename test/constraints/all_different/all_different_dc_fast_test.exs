defmodule CPSolverTest.Constraint.AllDifferent.DC.Fast do
  use ExUnit.Case, async: false

  describe "AllDifferent" do
    alias CPSolver.Constraint.AllDifferent.DC.Fast, as: AllDifferent
    alias CPSolver.IntVariable, as: Variable
    alias CPSolver.Constraint
    alias CPSolver.Model
    import CPSolver.Variable.View.Factory

    test "all fixed" do
      variables = Enum.map(1..5, fn i -> Variable.new(i) end)
      model = Model.new(variables, [Constraint.new(AllDifferent, variables)])
      {:ok, result} = CPSolver.solve(model)

      assert hd(result.solutions) == [1, 2, 3, 4, 5]
      assert result.statistics.solution_count == 1
    end

    test "reduction" do
      minizinc_solutions = [[1, 2, 4, 5], [1, 2, 3, 4], [1, 2, 3, 5]]
      variables = Enum.map([1, 1..2, 1..4, [1, 2, 4, 5]], fn d -> Variable.new(d) end)
      model = Model.new(variables, [Constraint.new(AllDifferent, variables)])
      {:ok, result} = CPSolver.solve(model)
      assert Enum.sort(result.solutions) == Enum.sort(minizinc_solutions)
    end

    test "produces all possible permutations" do
      var_nums = 4
      domain = 1..var_nums
      variables = Enum.map(domain, fn _ -> Variable.new(domain) end)

      permutations = Permutation.permute!(Enum.to_list(domain))

      model = Model.new(variables, [Constraint.new(AllDifferent, variables)])

      {:ok, result} = CPSolver.solve(model)

      assert result.statistics.solution_count == MapSet.size(permutations)

      assert result.solutions |> MapSet.new() == permutations
    end

    test "unsatisfiable (duplicates)" do
      variables = Enum.map(1..3, fn _ -> Variable.new(1) end)
      assert catch_throw({:fail, _} = Model.new(variables, [Constraint.new(AllDifferent, variables)]))

    end

    test "unsatisfiable(pigeonhole)" do
      variables = Enum.map(1..4, fn _ -> Variable.new(1..3) end)
      assert catch_throw({:fail, _} = Model.new(variables, [Constraint.new(AllDifferent, variables)]))
    end

    test "views in variable list" do
      n = 3
      variables = Enum.map(1..n, fn i -> Variable.new(1..n, name: "row#{i}") end)

      diagonal_down =
        Enum.map(Enum.with_index(variables, 1), fn {var, idx} -> linear(var, 1, -idx) end)

      diagonal_up =
        Enum.map(Enum.with_index(variables, 1), fn {var, idx} -> linear(var, 1, idx) end)

      model =
        Model.new(
          variables,
          [
            Constraint.new(AllDifferent, diagonal_down),
            Constraint.new(AllDifferent, diagonal_up),
            Constraint.new(AllDifferent, variables)
          ]
        )

      {:ok, res} = CPSolver.solve(model)

      assert res.status == :unsatisfiable
    end

    test "solves disjoint domains by a single reduction" do
      domains = [1..5, 6..10, 11..15]
      variables =
        Enum.map(domains, fn d -> Variable.new(d) end)
      model = Model.new(variables, [Constraint.new(AllDifferent, variables)])
      {:ok, res} = CPSolver.solve(model)

      assert Enum.sort(res.solutions) == CPSolver.Utils.cartesian(domains)
      assert res.statistics.solution_count ==
        Enum.reduce(domains, 1, fn d, acc -> Range.size(d) * acc end)
      assert res.statistics.node_count == 1
    end
  end
end
