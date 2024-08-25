defmodule CPSolverTest.Constraint.Reified do
  use ExUnit.Case, async: false

  describe "Reification" do
    alias CPSolver.Constraint.Reified, as: Reified
    alias CPSolver.Constraint.{Equal, NotEqual, LessOrEqual}
    alias CPSolver.IntVariable
    alias CPSolver.BooleanVariable
    alias CPSolver.Model

    test "equivalence: x<=y <-> b" do
      ~c"""
      MiniZinc model (for verification):
      var 0..1: x;
      var 0..1: y;

      var bool: b;

      constraint x <= y <-> b;

      Solutions:
      x = 1; y = 1; b = true;

      x = 0; y = 1; b = true;

      x = 1; y = 0; b = false;

      x = 0; y = 0; b = true;

      """

      x_domain = 0..1
      y_domain = 0..1
      model1 = make_model(x_domain, y_domain)
      {:ok, res} = CPSolver.solve_sync(model1)
      assert res.statistics.solution_count == 4
      assert Enum.all?(res.solutions, fn s -> check_solution(s) end)

      ## The order of variables doesn't matter
      model2 = make_model(x_domain, y_domain, fn [x, y, b] -> [b, x, y] end)
      {:ok, res} = CPSolver.solve_sync(model2)
      assert res.statistics.solution_count == 4
      assert Enum.all?(res.solutions, fn [b_value, x_value, y_value] = s ->
        check_solution([x_value, y_value, b_value])
      end)
    end

    defp make_model(x_domain, y_domain, order_fun \\ &Function.identity/1) do
      x = IntVariable.new(x_domain, name: "x")
      y = IntVariable.new(y_domain, name: "y")
      b = BooleanVariable.new(name: "b")
      le_constraint = LessOrEqual.new(x, y)
      Model.new(order_fun.([x, y, b]), [Reified.new(le_constraint, b)])
    end

    defp check_solution([x, y, b]) do
      (x <= y && b == 1) || b == 0
    end
  end
end
