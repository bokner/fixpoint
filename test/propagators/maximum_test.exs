defmodule CPSolverTest.Propagator.Maximum do
  use ExUnit.Case

  describe "Propagator filtering" do
    alias CPSolver.IntVariable, as: Variable
    alias CPSolver.Propagator
    alias CPSolver.Propagator.Maximum
    import CPSolver.Variable.Interface
    import CPSolver.Utils

    test "Test 1 (scenario: MiniCP, MaximumTest.maximumTest1)" do
        [x0, x1, x2] = x_vars = Enum.map(1..3, fn _ -> Variable.new(0..9) end)
        y_var = Variable.new(-5..20)
        max_propagator = Maximum.new(y_var, x_vars)

        step1 = Propagator.filter(max_propagator)

        assert max(y_var) == 9
        assert min(y_var) == 0

        removeAbove(y_var, 8)


        step2 = Propagator.filter(update_propagator(max_propagator, step1))

        assert Enum.all?(x_vars, fn x -> max(x) == 8 end)

        removeBelow(y_var, 5)
        removeAbove(x0, 2)
        removeBelow(x1, 6)
        removeBelow(x2, 6)

        step3 = Propagator.filter(update_propagator(max_propagator, step2))

        assert max(y_var) == 8
        assert min(y_var) == 6

        removeBelow(y_var, 7)
        removeAbove(x1, 6)

        _step4 = Propagator.filter(update_propagator(max_propagator, step3))

        assert min(x2) == 7

    end

    test "when 'y' variable is fixed" do
      y_var = Variable.new([5], name: "y")

      x_vars = [x0, x1, x2] =
        Enum.map([1..5, 1..10, [0, 6]], fn d ->
          Variable.new(d)
        end)

      max_propagator = Maximum.new(y_var, x_vars)
      Propagator.filter(max_propagator)

      assert domain_values(x0) == MapSet.new(1..5)
      assert domain_values(x1) == MapSet.new(1..5)
      assert min(x2) == 0 and max(x2) == 0
    end

    test "fails on inconsistency" do
      y_var = Variable.new(6..10)
      x1_var = Variable.new(0..4)
      x2_var = Variable.new(0..5)

      assert :fail == Propagator.filter(Maximum.new(y_var, [x1_var, x2_var]))
    end

  end

  defp update_propagator(propagator, previous_run) do
    Map.put(propagator, :state, previous_run.state)
  end
end
