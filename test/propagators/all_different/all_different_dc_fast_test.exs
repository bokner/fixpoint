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

    # test "cascading filtering" do
    #   ## all variables become fixed, and this will take a single filtering call.
    #   ##
    #   x =
    #     Enum.map([{"x2", 1..2}, {"x1", 1}, {"x3", 1..3}, {"x4", 1..4}, {"x5", 1..5}], fn {name, d} ->
    #       Variable.new(d, name: name)
    #     end)

    #   {:ok, x_vars, _store} = ConstraintStore.create_store(x)

    #   dc_propagator = DC.new(x_vars)
    #   %{changes: changes, active?: active?} = Propagator.filter(dc_propagator)
    #   ## The propagators is passive
    #   refute active?
    #   assert map_size(changes) == Arrays.size(x_vars) - 1
    #   assert Enum.all?(Map.values(changes), fn change -> change == :fixed end)
    #   ## All variables are now fixed
    #   assert Enum.all?(x_vars, &Interface.fixed?/1)
    # end

    # test "inconsistency (pigeonhole)" do
    #   domains = List.duplicate(1..3, 4)

    #   vars =
    #     Enum.map(domains, fn d -> Variable.new(d) end)

    #   {:ok, bound_vars, _store} = CPSolver.ConstraintStore.create_store(vars)
    #   dc_propagator = DC.new(bound_vars)
    #   assert Propagator.filter(dc_propagator) == :fail
    # end
  end
end
