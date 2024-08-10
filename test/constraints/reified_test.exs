defmodule CPSolverTest.Constraint.Reified do
  use ExUnit.Case, async: false

  describe "Absolute" do
    alias CPSolver.Constraint.Reified.Full, as: Reified
    alias CPSolver.Constraint.Reified.Half, as: HalfReified
    alias CPSolver.Constraint.{Equal, NotEqual, LessOrEqual}
    alias CPSolver.IntVariable
    alias CPSolver.BooleanVariable
    alias CPSolver.Variable.Interface
    alias CPSolver.Model
    alias CPSolver.Constraint.Factory, as: ConstraintFactory

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

    test "`Reified` functionality" do
      x = IntVariable.new(0..1, name: "x")
      y = IntVariable.new(0..1, name: "y")
      b = BooleanVariable.new(name: "b")

      le_constraint = LessOrEqual.new(x, y)
      model = Model.new([x, y], [Reified.new(le_constraint, b)])

      {:ok, res} = CPSolver.solve_sync(model)
      assert res.statistics.solution_count == 4
      assert Enum.all?(res.solutions, fn s -> check_solution(s) end)
    end

    defp check_solution([{"x", x}, {"y", y}, {"b", b}]) do
      (x <= y && b == 1) || b == 0
    end
  end
end
