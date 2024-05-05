defmodule CPSolverTest.Constraint.AllDifferent.FWC do
  use ExUnit.Case, async: false

  describe "AllDifferentFWC" do
    alias CPSolver.Constraint.AllDifferent.FWC, as: AllDifferentFWC
    alias CPSolver.IntVariable
    alias CPSolver.Constraint
    alias CPSolver.Model
    import CPSolver.Variable.View.Factory

    test "all fixed"  do
      variables = Enum.map(1..5, fn i -> IntVariable.new(i) end)
      model = Model.new(variables, [Constraint.new(AllDifferentFWC, variables)])
      {:ok, result} = CPSolver.solve_sync(model, timeout: 100)

      assert hd(result.solutions) == [1, 2, 3, 4, 5]
      assert result.statistics.solution_count == 1

    end

    test "produces all possible permutations" do
      domain = 1..3
      variables = Enum.map(1..3, fn _ -> IntVariable.new(domain) end)

      model = Model.new(variables, [Constraint.new(AllDifferentFWC, variables)])

      {:ok, result} = CPSolver.solve_sync(model, timeout: 100)

      assert result.statistics.solution_count == 6

      assert result.solutions |> Enum.sort() == [
               [1, 2, 3],
               [1, 3, 2],
               [2, 1, 3],
               [2, 3, 1],
               [3, 1, 2],
               [3, 2, 1]
             ]
    end

    test "unsatisfiable (duplicates)" do
      variables = Enum.map(1..3, fn _ -> IntVariable.new(1) end)
      model = Model.new(variables, [Constraint.new(AllDifferentFWC, variables)])

      {:ok, result} = CPSolver.solve_sync(model, timeout: 1000)

      assert result.status == :unsatisfiable
    end

    test "unsatisfiable(pigeonhole)" do
      variables = Enum.map(1..4, fn _ -> IntVariable.new(1..3) end)
      model = Model.new(variables, [Constraint.new(AllDifferentFWC, variables)])

      {:ok, result} = CPSolver.solve_sync(model, timeout: 100)

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

      {:ok, res} = CPSolver.solve_sync(model)

      assert res.status == :unsatisfiable
    end
  end
end
