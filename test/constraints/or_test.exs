defmodule CPSolverTest.Constraint.Or do
  use ExUnit.Case, async: false

  alias CPSolver.BooleanVariable
  alias CPSolver.Model
  alias CPSolver.Constraint.Or

  describe "Or constraint" do
    test "`or` functionality" do
      bool_vars = Enum.map(1..4, fn i -> BooleanVariable.new(name: "b#{i}") end)
      or_constraint = Or.new(bool_vars)

      model = Model.new(bool_vars, [or_constraint])

      {:ok, result} = CPSolver.solve_sync(model)

      assert result.statistics.solution_count == 15
      assert_or(result.solutions, length(bool_vars))
    end

    test "inconsistency (all-false)" do
      bool_vars = List.duplicate(0, 4)

      or_constraint = Or.new(bool_vars)

      model = Model.new(bool_vars, [or_constraint])

      {:ok, result} = CPSolver.solve_sync(model)

      assert result.status == :unsatisfiable
    end

    defp assert_or(solutions, array_len) do
      assert Enum.all?(solutions, fn solution ->
               arr = Enum.take(solution, array_len)
               Enum.sum(arr) > 0
             end)
    end
  end
end
