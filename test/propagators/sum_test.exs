defmodule CPSolverTest.Propagator.Sum do
  use ExUnit.Case

  describe "Propagator filtering" do
    alias CPSolver.ConstraintStore
    alias CPSolver.IntVariable, as: Variable
    alias CPSolver.Propagator
    alias CPSolver.Propagator.Sum
    import CPSolver.Variable.Interface

    test "The domain bounds of 'sum' variable are reduced to the sum of bounds of the summands" do
      y = Variable.new(-100..100, name: "y")

      x =
        Enum.map([{"x1", 0..5}, {"x2", 1..5}, {"x3", 0..5}], fn {name, d} ->
          Variable.new(d, name: name)
        end)

      {:ok, [y_var | x_vars] = _bound_vars, store} = ConstraintStore.create_store([y | x])

      # assert :stable ==
      Propagator.filter(Sum.new(y_var, x_vars), store: store)
      |> tap(fn res -> IO.inspect(res) end)

      assert 1 == min(y_var)
      assert 15 == max(y_var)
    end

    test "Test 2" do
      y = Variable.new(0..100, name: "y")

      x =
        Enum.map([{-5..5, "x1"}, {[1, 2], "x2"}, {[0, 1], "x3"}], fn {d, name} ->
          Variable.new(d, name: name)
        end)

      {:ok, [y_var | x_vars] = bound_vars, store} = ConstraintStore.create_store([y | x])

      [x1_var, x2_var, x3_var] = x_vars

      # Enum.each(bound_vars, fn v -> IO.inspect("#{v.name} => #{inspect v.id}, #{min(v)}..#{max(v)}") end)
      # assert :stable ==
      sum_propagator = Sum.new(y_var, x_vars)
      IO.inspect(sum_propagator.args)

      Propagator.filter(sum_propagator, store: store)
      |> tap(fn res -> IO.inspect(res) end)

      Propagator.filter(sum_propagator, store: store)
      |> tap(fn res -> IO.inspect(res) end)

      Propagator.filter(sum_propagator, store: store)
      |> tap(fn res -> IO.inspect(res) end)

      Enum.each(bound_vars, fn v ->
        IO.inspect("#{v.__struct__}: #{v.name} => #{inspect(v.id)}, #{min(v)}..#{max(v)}")
      end)

      assert -3 == min(x1_var)
      assert 0 == min(y_var)
      assert 8 == max(y_var)
    end
  end
end
