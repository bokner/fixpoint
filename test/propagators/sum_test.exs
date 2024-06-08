defmodule CPSolverTest.Propagator.Sum do
  use ExUnit.Case

  describe "Propagator filtering" do
    alias CPSolver.IntVariable, as: Variable
    alias CPSolver.Propagator
    alias CPSolver.Propagator.Sum
    import CPSolver.Variable.Interface
    import CPSolver.Variable.View.Factory
    import CPSolver.Test.Helpers

    test "The domain bounds of 'sum' variable are reduced to the sum of bounds of the summands" do
      y = Variable.new(-100..100, name: "y")

      x =
        Enum.map([{"x1", 0..5}, {"x2", 1..5}, {"x3", 0..5}], fn {name, d} ->
          Variable.new(d, name: name)
        end)

      {:ok, bound_vars, store} = create_store([y | x])
      [y_var | x_vars] = bound_vars

      Propagator.filter(Sum.new(y_var, x_vars), store: store)

      assert 1 == min(y_var)
      assert 15 == max(y_var)
    end

    test "Test 2" do
      y = Variable.new(0..100, name: "y")

      x =
        Enum.map([{-5..5, "x1"}, {[1, 2], "x2"}, {[0, 1], "x3"}], fn {d, name} ->
          Variable.new(d, name: name)
        end)

      {:ok, bound_vars, store} = create_store([y | x])

      [y_var | x_vars] = bound_vars

      [x1_var, _x2_var, _x3_var] = x_vars

      sum_propagator = Sum.new(y_var, x_vars)

      Propagator.filter(sum_propagator, store: store)

      assert -3 == min(x1_var)
      assert 0 == min(y_var)
      assert 8 == max(y_var)
    end

    test "when 'y' variable is fixed" do
      y = Variable.new([5], name: "y")

      x =
        Enum.map([{1..5, "x1"}, {[1], "x2"}, {[0, 1], "x3"}], fn {d, name} ->
          Variable.new(d, name: name)
        end)

      {:ok, bound_vars, store} = create_store([y | x])
      [y_var | x_vars] = bound_vars

      [x1_var, _x2_var, x3_var] = x_vars

      sum_propagator = Sum.new(y_var, x_vars)

      Propagator.filter(sum_propagator, store: store)

      assert 4 == max(x1_var)
      assert 3 == min(x1_var)
      assert 1 == max(x3_var)
      assert 0 == min(x3_var)
    end

    test "fails on inconsistency" do
      y = Variable.new(10, name: "y")
      x1 = Variable.new(0..4, name: "x1")
      x2 = Variable.new(0..5, name: "x2")

      {:ok, bound_vars, store} =
        create_store([y, x1, x2])

      [y_var, x1_var, x2_var] = bound_vars

      assert :fail == Propagator.filter(Sum.new(y_var, [x1_var, x2_var]), store: store)
    end

    test "when summands are views" do
      y = Variable.new(50, name: "y")
      x1 = Variable.new(0..2, name: "x1")
      x2 = Variable.new(1..2, name: "x2")

      {:ok, bound_vars, store} =
        create_store([y, x1, x2])

      [y_var, x1_var, x2_var] = bound_vars

      refute :fail ==
               Propagator.filter(Sum.new(y_var, [mul(x1_var, 10), mul(x2_var, 20)]), store: store)

      assert 1 == Variable.min(x1_var)
      assert 1 == Variable.max(x1_var)
    end
  end
end
