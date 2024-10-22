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
      domain = 1..3
      variables = Enum.map(1..3, fn _ -> IntVariable.new(domain) end)

      model = Model.new(variables, [Constraint.new(AllDifferent, variables)])

      {:ok, solver} = CPSolver.solve_async(model)

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
  end
end
