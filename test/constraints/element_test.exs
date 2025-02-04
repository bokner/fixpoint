defmodule CPSolverTest.Constraint.Element do
  use ExUnit.Case, async: false

  alias CPSolver.IntVariable, as: Variable
  alias CPSolver.DefaultDomain, as: Domain
  alias CPSolver.Model
  alias CPSolver.Constraint.Factory, as: ConstraintFactory

  describe "Element (constant array)" do
    alias CPSolver.Constraint.{Element, Element2D}

    test "`element` functionality" do
      y = Variable.new(-3..10)
      z = Variable.new(-20..40)
      t = [9, 8, 7, 5, 6]

      model = Model.new([y, z], [Element.new(t, y, z)])

      {:ok, result} = CPSolver.solve(model)

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

      {:ok, result} = CPSolver.solve(model)
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

      {:ok, result} = CPSolver.solve(model)
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
      assert Domain.to_list(z_var.domain) |> Enum.sort() ==
               t |> List.flatten() |> Enum.uniq() |> Enum.sort()

      model = Model.new([x_var, y_var, z_var], [element2d_constraint])

      {:ok, result} = CPSolver.solve(model)
      assert_element2d(result.solutions, t)
    end

    ## Constraint check: t[y] = z
    ## Note: last variable is a placeholder (0)
    ## This is to maintain compatibility with element2D
    ## Placeholder will be eliminated in upcoming versions.
    ##
    defp assert_element(solutions, t) do
      assert Enum.all?(solutions, fn [y_value, z_value | _placeholder] ->
               Enum.at(t, y_value) == z_value
             end)
    end

    defp assert_element2d(solutions, t) do
      assert Enum.all?(solutions, fn [x, y, z | _rest] ->
               Enum.at(t, x) |> Enum.at(y) == z
             end)
    end
  end

  describe "Element (variable array)" do
    alias CPSolver.Constraint.ElementVar

    test "inconsistency (index domain outside of index set of the array)" do
      index_var = Variable.new(6..10, name: "index")
      value_var = Variable.new(-20..40, name: "value")

      array_var =
        Enum.map(Enum.with_index([9, 8, 7, 5, 6], 1), fn {val, idx} ->
          Variable.new(val, name: "T#{idx}")
        end)

      element_constraint = ElementVar.new(array_var, index_var, value_var)
      assert catch_throw({:fail, _} = Model.new([index_var, value_var | array_var], [element_constraint]))
    end

    test "`element with fixed values in variable array" do
      index_var = Variable.new(-3..10, name: "index")
      value_var = Variable.new(-20..40, name: "value")

      array_values = [9, 8, 7, 5, 6]
      #  Enum.map(Enum.with_index([9, 8, 7, 5, 6], 1), fn {val, idx} ->
      #    Variable.new(val, name: "T#{idx}")
      #  end)

      element_constraint = ElementVar.new(array_values, index_var, value_var)
      model = Model.new([index_var, value_var | array_values], [element_constraint])
      {:ok, res} = CPSolver.solve(model)

      assert res.statistics.solution_count == 5

      assert Enum.all?(res.solutions, fn [idx, val | array_vals] ->
               Enum.at(array_vals, idx) == val
             end)
    end

    test "element with non-fixed domains in the array" do
      index_var = Variable.new(-5..2, name: "idx")
      value_var = Variable.new(-2..2, name: "value")
      array_var = Enum.map(0..4, fn idx -> Variable.new(-1..1, name: "A#{idx}") end)
      element_constraint = ElementVar.new(array_var, index_var, value_var)
      model = Model.new([index_var, value_var | array_var], [element_constraint])
      {:ok, res} = CPSolver.solve(model)

      ~S"""
      Verified by MiniZinc model:
      var -5..2: idx;
      var -2..2: value;
      array[0..4] of var -1..1: arr;
      constraint arr[idx] = value;
      """

      assert res.statistics.solution_count == 729

      assert Enum.all?(res.solutions, fn [idx, val | array_vals] ->
               Enum.at(array_vals, idx) == val
             end)
    end

    test "enumerated index" do
      index_var = Variable.new([-5, 0, 2], name: "idx")
      value_var = Variable.new(-2..2, name: "value")
      array_var = Enum.map(0..4, fn idx -> Variable.new(-1..1, name: "A#{idx}") end)
      element_constraint = ElementVar.new(array_var, index_var, value_var)
      model = Model.new([index_var, value_var | array_var], [element_constraint])
      {:ok, res} = CPSolver.solve(model)

      ~S"""
      Verified by MiniZinc model:
      var {-5, 0, 2}: idx;
      var -10..10: value;
      array[0..4] of var -1..1: arr;

      constraint arr[idx] = value;
      """

      assert res.statistics.solution_count == 486

      assert Enum.all?(res.solutions, fn [idx, val | array_vals] ->
               Enum.at(array_vals, idx) == val
             end)
    end
  end

  test "variable 2d array" do
    ~S"""
    MiniZinc:

    array[1..2, 1..2] of var 0..3: arr2d;
    var 0..4: x;
    var 0..2: y;
    var 1..10: z;

    constraint arr2d[x, y] = z;
    """

    arr2d =
      for i <- 1..2 do
        for j <- 1..2 do
          Variable.new(0..3, name: "arr(#{i},#{j})")
        end
      end

    x = Variable.new(0..4, name: "x")
    y = Variable.new(0..2, name: "y")
    z = Variable.new(1..10, name: "z")

    model =
      Model.new(
        [x, y, z, arr2d] |> List.flatten(),
        ConstraintFactory.element2d_var(arr2d, x, y, z)
      )

    {:ok, res} = CPSolver.solve(model)
    assert res.statistics.solution_count == 768

    assert_element2d_var(res.solutions, length(arr2d), length(hd(arr2d)))
  end

  defp assert_element2d_var(solutions, row_num, col_num) do
    assert Enum.all?(
             solutions,
             fn solution ->
               [x, y, z | rest] = solution
               arr_solution = Enum.take(rest, row_num * col_num)
               Enum.at(arr_solution, x * col_num + y) == z
             end
           )
  end
end
