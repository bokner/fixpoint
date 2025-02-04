defmodule CPSolverTest.Constraint.Or do
  use ExUnit.Case, async: false

  alias CPSolver.BooleanVariable
  alias CPSolver.Model
  alias CPSolver.Constraint.Or
  import CPSolver.Variable.View.Factory

  describe "Or constraint" do
    test "`or` functionality" do
      bool_vars = Enum.map(1..4, fn i -> BooleanVariable.new(name: "b#{i}") end)
      or_constraint = Or.new(bool_vars)

      model = Model.new(bool_vars, [or_constraint])

      {:ok, result} = CPSolver.solve(model)

      assert result.statistics.solution_count == 15
      assert_or(result.solutions, length(bool_vars))
    end

    test "inconsistency (all-false)" do
      bool_vars = List.duplicate(0, 4)

      or_constraint = Or.new(bool_vars)

      assert catch_throw({:fail, _} = Model.new(bool_vars, [or_constraint]))
    end

    test "with negation vars" do
      x = BooleanVariable.new(name: "x")
      not_y = negation(BooleanVariable.new(name: "y"))
      vars = [x, not_y]
      or_constraint = Or.new(vars)
      model = Model.new(vars, [or_constraint])

      {:ok, result} = CPSolver.solve(model)
      assert [0, 0] in result.solutions
    end

    test "peformance" do
      n = 1000
      bool_vars = Enum.map(1..n, fn i -> BooleanVariable.new(name: "b#{i}") end)
      or_constraint = Or.new(bool_vars)

      model = Model.new(bool_vars, [or_constraint])

      {:ok, res} =
        CPSolver.solve(model,
          stop_on: {:max_solutions, 1},
          search: {:first_fail, :indomain_max},
          space_threads: 1
        )

      assert res.statistics.solution_count >= 1
      ## Arbitrary elapsed time, the main point it shouldn't be too big
      assert res.statistics.elapsed_time < 250_000
    end

    defp assert_or(solutions, array_len) do
      assert Enum.all?(solutions, fn solution ->
               arr = Enum.take(solution, array_len)
               Enum.sum(arr) > 0
             end)
    end
  end
end
