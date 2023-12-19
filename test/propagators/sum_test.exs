defmodule CPSolverTest.Propagator.Sum do
  use ExUnit.Case

  describe "Propagator filtering" do
    alias CPSolver.ConstraintStore
    alias CPSolver.IntVariable, as: Variable
    alias CPSolver.Variable.Interface
    alias CPSolver.Propagator
    alias CPSolver.Propagator.Sum
    import CPSolver.Variable.Interface
    import CPSolver.Variable.View.Factory

    test "The domain bounds of 'sum' variable are reduced to the sum of bounds of the summands" do
      y = Variable.new(-100..100, name: "y")

      x =
        Enum.map([{"x1", 0..5}, {"x2", 1..5}, {"x3", 0..5}], fn {name, d} ->
          Variable.new(d, name: name)
        end)

      {:ok, [y_var | x_vars] = _bound_vars, store} = ConstraintStore.create_store([y | x])

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

      {:ok, [y_var | x_vars] = _bound_vars, store} = ConstraintStore.create_store([y | x])

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

      {:ok, [y_var | x_vars] = _bound_vars, store} = ConstraintStore.create_store([y | x])

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

      {:ok, [y_var, x1_var, x2_var] = _bound_vars, store} =
        ConstraintStore.create_store([y, x1, x2])

      assert :fail == Propagator.filter(Sum.new(y_var, [x1_var, x2_var]), store: store)
    end

    test "when summands are views" do
      y = Variable.new(50, name: "y")
      x1 = Variable.new(0..2, name: "x1")
      x2 = Variable.new(1..2, name: "x2")

      {:ok, [y_var, x1_var, x2_var] = _bound_vars, store} =
        ConstraintStore.create_store([y, x1, x2])

      refute :fail ==
               Propagator.filter(Sum.new(y_var, [mul(x1_var, 10), mul(x2_var, 20)]), store: store)

      assert 1 == Variable.min(x1_var)
      assert 1 == Variable.max(x1_var)
    end

    test "maintains sum of fixed values and the list of unfixed variables" do
      y = Variable.new(-100..100, name: "y")

      x =
        Enum.map([{"x1", 0..5}, {"x2", 1..5}, {"x3", 0..5}, {"x4", 4}, {"x5", 5}], fn {name, d} ->
          Variable.new(d, name: name)
        end)

      {:ok, [y_var | x_vars] = _bound_vars, _store} = ConstraintStore.create_store([y | x])

      [x1_var, x2_var, x3_var, _x4_var, _x5_var] = x_vars
      sum_propagator = Sum.new(y_var, x_vars)
      %{sum_fixed: sum_fixed, unfixed_vars: unfixed_vars} = sum_propagator.state

      ## There are 2 fixed variables with total 4+5 = 9
      assert sum_fixed == 9
      unfixed_num = length([y | x]) - 2
      assert MapSet.size(unfixed_vars) == unfixed_num

      :fixed = Interface.fix(x1_var, 1)

      updated_sum_propagator = Propagator.update(sum_propagator, %{x1_var.id => :fixed})
      %{sum_fixed: sum_fixed_new, unfixed_vars: unfixed_vars} = updated_sum_propagator.state

      assert sum_fixed_new == 10
      assert MapSet.size(unfixed_vars) == unfixed_num - 1

      ## Update with the variable that has already been fixed doesn't change the propagator
      updated_sum_propagator2 = Propagator.update(updated_sum_propagator, %{x1_var.id => :fixed})
      assert updated_sum_propagator2 == updated_sum_propagator

      ## If the change is not ':fixed', there is no effect
      updated_sum_propagator3 =
        Propagator.update(updated_sum_propagator, %{x2_var.id => :domain_change})

      assert updated_sum_propagator3 == updated_sum_propagator

      ## 2 fixed vars in a single update
      :fixed = Interface.fix(x2_var, 5)
      :fixed = Interface.fix(x3_var, 5)

      updated_sum_propagator4 =
        Propagator.update(updated_sum_propagator, %{x2_var.id => :fixed, x3_var.id => :fixed})

      assert updated_sum_propagator4.state.sum_fixed == 20
      assert MapSet.size(updated_sum_propagator4.state.unfixed_vars) == 1

      ## Filter
      refute Interface.fixed?(y_var)
      Propagator.filter(updated_sum_propagator4)
      assert Interface.fixed?(y_var)
      assert Interface.min(y_var) == Enum.map(x_vars, fn x -> Interface.min(x) end) |> Enum.sum()
    end
  end
end
