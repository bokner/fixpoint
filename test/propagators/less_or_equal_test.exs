defmodule CPSolverTest.Propagator.LessOrEqual do
  use ExUnit.Case

  describe "Propagator filtering" do
    alias CPSolver.IntVariable, as: Variable
    alias CPSolver.Propagator
    alias CPSolver.Propagator.{Less, LessOrEqual}
  
    test "filtering" do
      ## Both vars are unfixed
      x = 0..10
      y = -5..5
      vars = Enum.map([x, y], fn d -> Variable.new(d) end)

      [x_var, y_var] = vars

      %{changes: changes} = Propagator.filter(LessOrEqual.new(vars))
      assert Map.get(changes, x_var.id) == :max_change
      assert Map.get(changes, y_var.id) == :min_change
      assert 0 == Variable.min(x_var)
      assert 5 == Variable.max(x_var)
      ## Both domains are cut to 0..5
      assert Variable.min(x_var) == Variable.min(y_var)
      assert Variable.max(x_var) == Variable.max(y_var)
    end

    test "inconsistency" do
      x = 1..10
      y = -10..0
      ## Inconsistency: no solution to x <= y
      variables = Enum.map([x, y], fn d -> Variable.new(d) end)
      ## The propagator will fail on one of the variables
      assert Propagator.filter(LessOrEqual.new(variables)) == :fail
    end

    test "offset" do
      x = 0..10
      y = -10..0
      variables = Enum.map([x, y], fn d -> Variable.new(d) end)
      [x_var, y_var] = variables
      # (x <= y + 5)
      offset = 5
      Propagator.filter(LessOrEqual.new([x_var, y_var, offset]))
      ## The domain of (y+5) variable is -5..5
      assert 0 == Variable.min(x_var)
      assert 5 == Variable.max(x_var)
      assert Variable.min(x_var) == Variable.min(y_var) + offset
      assert Variable.max(x_var) == Variable.max(y_var) + offset
    end

    test "Filtering reports :passive if the domains intersect in no more than one point" do
      x = 1..4
      y = 2..4

      variables = Enum.map([x, y], fn d -> Variable.new(d) end)

      [x_var, y_var] = variables

      refute %{active: false} == Propagator.filter(LessOrEqual.new([x_var, y_var]))

      ## Cut domain of x so it intersects with domain of y in exactly one point
      Variable.removeAbove(x_var, 2)
      result = Propagator.filter(LessOrEqual.new([x_var, y_var]))
      refute result.active?
      ## Cut domain of x so it does not intersect with domain of y
      Variable.remove(x_var, 2)
      assert %{active?: false} = Propagator.filter(LessOrEqual.new([x_var, y_var]))
    end

    test "Less" do
      x = 1
      y = 1

      [x_var, y_var] = Enum.map([x, y], fn d -> Variable.new(d) end)

      less_propagator = Propagator.new(Less, [x_var, y_var])

      assert Propagator.filter(less_propagator) == :fail
    end
  end
end
