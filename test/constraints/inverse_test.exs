defmodule CPSolverTest.Constraint.Inverse do
  use ExUnit.Case, async: false

  alias CPSolver.IntVariable, as: Variable
  alias CPSolver.Model
  alias CPSolver.Constraint.Factory, as: ConstraintFactory

  describe "Inverse constraint" do

    test "`inverse` functionality" do

      indexed_domains = List.duplicate(0..5, 6) |> Enum.with_index()
      x_vars = Enum.map(indexed_domains, fn {d, idx} -> Variable.new(d, name: "x#{idx}") end)
      y_vars = Enum.map(indexed_domains, fn {d, idx} -> Variable.new(d, name: "y#{idx}") end)

      model = Model.new(x_vars ++ y_vars, ConstraintFactory.inverse(x_vars, y_vars))

      {:ok, result} = CPSolver.solve(model)

      assert result.statistics.solution_count == 720
      assert_inverse(result.solutions, length(x_vars))
    end

    defp assert_inverse(solutions, array_len) do
      assert Enum.all?(solutions, fn solution ->
              x_y = Enum.take(solution, array_len * 2)
              {x, y} = Enum.split(x_y, array_len)
              Enum.all?(0..array_len-1, fn idx -> Enum.at(x, Enum.at(y, idx)) == idx end)
            end)
    end

  end

end
