defmodule CPSolverTest.Propagator.AllDifferent.DC.Fast do
  use ExUnit.Case

  #alias CPSolver.ConstraintStore
  alias CPSolver.IntVariable, as: Variable
  alias CPSolver.Variable.Interface
  #alias CPSolver.Propagator
  alias CPSolver.Propagator.AllDifferent.DC.Fast

  describe "Reduction algoritm (Zhang et al. paper example " do
    test "reduction" do
        domains = [1, 1..2, 1..4, [1, 2, 4, 5]]
        [_x0, x1, x2, x3] = vars = Enum.map(Enum.with_index(domains, 0), fn {d, idx} ->
          Variable.new(d, name: "x#{idx}")
        end)
        Fast.reduce(vars)

        assert Interface.fixed?(x1) && Interface.min(x1) == 2
        assert Interface.min(x2) == 3 && Interface.max(x2) == 4
        assert Interface.min(x3) == 4 && Interface.max(x3) == 5
    end

    test "cascading" do
      ## all variables become fixed, and this will take a single filtering call.
      ##
      [x2, _x1, x3, x4, x5] = vars =
        Enum.map([{"x2", 1..2}, {"x1", 1}, {"x3", 1..3}, {"x4", 1..4}, {"x5", 1..5}], fn {name, d} ->
          Variable.new(d, name: name)
        end)

      Fast.reduce(vars)
      assert Interface.fixed?(x2) && Interface.min(x2) == 2
      assert Interface.fixed?(x3) && Interface.min(x3) == 3
      assert Interface.fixed?(x4) && Interface.min(x4) == 4
      assert Interface.fixed?(x5) && Interface.min(x5) == 5

    end

    test "inconsistency (pigeonhole)" do
      domains = List.duplicate(1..3, 4)

      vars =
        Enum.map(domains, fn d -> Variable.new(d) end)
      assert catch_throw(Fast.reduce(vars)) == :fail
    end
  end

  describe "Filtering" do
    alias CPSolver.Propagator
    test "reduction" do
      domains = [1, 1..2, 1..4, [1, 2, 4, 5]]
      [_x0, x1, x2, x3] = vars = Enum.map(Enum.with_index(domains, 0), fn {d, idx} ->
        Variable.new(d, name: "x#{idx}")
      end)

      {:ok, x_vars, _store} = CPSolver.ConstraintStore.create_store(vars)

      dc_propagator = Fast.new(x_vars)
      %{state: _} = Propagator.filter(dc_propagator)

      assert Interface.fixed?(x1) && Interface.min(x1) == 2
      assert Interface.min(x2) == 3 && Interface.max(x2) == 4
      assert Interface.min(x3) == 4 && Interface.max(x3) == 5
  end
  end
end
