defmodule CPSolverTest.Variable.Interface do
  use ExUnit.Case

  describe "Views" do
    alias CPSolver.IntVariable, as: Variable
    alias CPSolver.Variable.Interface

    import CPSolver.Variable.View.Factory
    import CPSolver.Utils

    test "view vs variable" do
      v1_values = 1..10
      v2_values = 1..10
      values = [v1_values, v2_values]
      variables = Enum.map(values, fn d -> Variable.new(d) end)

      [var1, _var2] = variables

      [view1, view2] = Enum.map(variables, fn var -> minus(var) end)

      ## Domain
      ##
      assert domain_values(var1) |> Enum.sort() ==
               Enum.to_list(v1_values) |> Enum.sort()

      assert domain_values(view1) |> Enum.sort() ==
               Enum.map(v1_values, fn x -> -x end) |> Enum.sort()

      ## Size
      ##
      assert Interface.size(var1) == 10
      assert Interface.size(view1) == 10

      ## Min
      ##
      assert Interface.min(var1) == 1
      assert Interface.min(view1) == -10

      ## Max
      ##
      assert Interface.max(var1) == 10
      assert Interface.max(view1) == -1

      ## Contains?
      ##
      assert Interface.contains?(var1, 5)
      refute Interface.contains?(var1, -5)
      assert Interface.contains?(view1, -5)
      refute Interface.contains?(view1, 5)

      ## Remove
      ##
      assert :min_change == Interface.remove(var1, 1)
      assert :no_change == Interface.remove(var1, -1)

      assert :min_change == Interface.remove(view2, -1)
      assert :no_change == Interface.remove(view2, 1)

      ## Remove above/below
      ##
      assert :max_change == Interface.removeAbove(var1, 5)
      assert :no_change == Interface.removeBelow(var1, -5)

      assert :max_change == Interface.removeBelow(view2, -5)
      assert :no_change == Interface.removeAbove(view2, 5)

      ## Fix and Fixed?
      ##
      assert domain_values(var1) == MapSet.new([2, 3, 4, 5])
      assert :fixed == Interface.fix(var1, 2)
      assert Interface.fixed?(var1)
      assert :fail == catch_throw(Interface.fix(var1, 1))

      assert domain_values(view2) == MapSet.new([-5, -4, -3, -2])
      assert :fixed == Interface.fix(view2, -2)
      assert Interface.fixed?(view2)
      assert :fail == catch_throw(Interface.fix(view2, 1))
    end
  end
end
