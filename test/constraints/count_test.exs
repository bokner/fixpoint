defmodule CPSolverTest.Constraint.Count do
  use ExUnit.Case, async: false

  alias CPSolver.IntVariable, as: Variable
  alias CPSolver.Model
  alias CPSolver.Constraint.Factory, as: ConstraintFactory

  describe "Count constraint" do
  
    test "`count` functionality" do
      ~S"""
      MiniZinc:

      var -5..5: c;
      var 0..10: y;
      array[1..5] of var 1..3: arr;

      constraint count_eq(arr, y, c);
      """

      c = Variable.new(-5..5, name: "count")
      y = Variable.new(0..10, name: "value")
      array = Enum.map(1..5, fn i -> Variable.new(1..3, name: "arr#{i}") end)

      model = Model.new([array, y, c] |> List.flatten(), ConstraintFactory.count(array, y, c) |> List.flatten())

      {:ok, result} = CPSolver.solve_sync(model)

      assert result.statistics.solution_count == 2673
      assert_count(result.solutions, length(array))
    end

    defp assert_count(solutions, array_len) do
      assert Enum.all?(solutions, fn solution ->
              arr = Enum.take(solution, array_len)
              value = Enum.at(solution, array_len)
              c = Enum.at(solution, array_len + 1)
              Enum.count(arr, fn el -> el == value end) == c
             end)
    end

  end

end
