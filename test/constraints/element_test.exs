defmodule CPSolverTest.Constraint.Element do
  use ExUnit.Case, async: false

  describe "Element" do
    alias CPSolver.Constraint.{Element, Element2D}
    alias CPSolver.IntVariable, as: Variable
    alias CPSolver.DefaultDomain, as: Domain
    alias CPSolver.Model
    alias CPSolver.Constraint.Factory, as: ConstraintFactory

    test "`element` functionality" do
      y = Variable.new(-3..10)
      z = Variable.new(-20..40)
      t = [9, 8, 7, 5, 6]

      model = Model.new([y, z], [Element.new(t, y, z)])

      {:ok, result} = CPSolver.solve_sync(model)

      assert result.statistics.solution_count == 5
      assert_element(result.solutions, t)
    end

    test "`element2d functionality" do
      x = Variable.new(-2..40, name: "x")
      y = Variable.new(-3..10, name: "y")
      z = Variable.new(2..40, name: "z")

      t = [
        [9, 8, 7, 5, 6],
        [9, 1, 5, 2, 8],
        [8, 3, 1, 4, 9],
        [9, 1, 2, 8, 6]
      ]

      model = Model.new([x, y, z], [Element2D.new(t, x, y, z)])

      {:ok, result} = CPSolver.solve_sync(model)
      refute Enum.empty?(result.solutions)
      assert_element2d(result.solutions, t)

    end

    test "`element` factory function" do
      x_var = Variable.new(-20..40)
      t = [9, 8, 7, 5, 6]

      {y_var, element_constraint} = ConstraintFactory.element(t, x_var)
      ## domain of generated variable corresponds to content of t
      assert Domain.to_list(y_var.domain) |> Enum.sort() == Enum.sort(t)
      ## Create and run model with generated constraint
      model = Model.new([x_var, y_var], [element_constraint])

      {:ok, result} = CPSolver.solve_sync(model)
      assert_element(result.solutions, t)

    end

    test "`element2d` factory function" do
      x_var = Variable.new(-2..40, name: "x")
      y_var = Variable.new(-3..10, name: "y")

      t = [
        [9, 8, 7, 5, 6],
        [9, 1, 5, 2, 8],
        [8, 3, 1, 4, 9],
        [9, 1, 2, 8, 6]
      ]

      {z_var, element2d_constraint} = ConstraintFactory.element2d(t, x_var, y_var)
      ## domain of generated variable corresponds to content of t (all unique values)
      assert Domain.to_list(z_var.domain) |> Enum.sort() == t |> List.flatten() |> Enum.uniq() |> Enum.sort()

      model = Model.new([x_var, y_var, z_var], [element2d_constraint])

      {:ok, result} = CPSolver.solve_sync(model)
      assert_element2d(result.solutions, t)
    end

    ## Constraint check: t[y] = z
    ## Note: last variable is a placeholder (0)
    ## This is to maintain compatibility with element2D
    ## Placeholder will be eliminated in upcoming versions.
    ##
    defp assert_element(solutions, t) do
      assert Enum.all?(solutions, fn [y_value, z_value, _placeholder] ->
        Enum.at(t, y_value) == z_value
      end)
    end

    defp assert_element2d(solutions, t) do
      assert Enum.all?(solutions, fn [x, y, z] ->
        Enum.at(t, x) |> Enum.at(y) == z
      end)
    end
  end
end
