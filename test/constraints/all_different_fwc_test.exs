defmodule CPSolverTest.Constraint.AllDifferent.FWC do
  use ExUnit.Case, async: false

  describe "AllDifferentFWC" do
    alias CPSolver.Constraint.AllDifferent.FWC, as: AllDifferentFWC
    alias CPSolver.IntVariable
    alias CPSolver.Constraint
    alias CPSolver.Model
    import CPSolver.Variable.View.Factory

    test "produces all possible permutations" do
      domain = 1..3
      variables = Enum.map(1..3, fn _ -> IntVariable.new(domain) end)

      model = Model.new(variables, [Constraint.new(AllDifferentFWC, variables)])

      {:ok, solver} = CPSolver.solve(model)

      Process.sleep(100)
      assert CPSolver.statistics(solver).solution_count == 6

      assert CPSolver.solutions(solver) |> Enum.sort() == [
               [1, 2, 3],
               [1, 3, 2],
               [2, 1, 3],
               [2, 3, 1],
               [3, 1, 2],
               [3, 2, 1]
             ]
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
