defmodule CPSolverTest.Propagator.AllDifferent.BC do
  use ExUnit.Case

  alias CPSolver.IntVariable, as: Variable
  alias CPSolver.Variable.Interface
  alias CPSolver.Propagator
  alias CPSolver.Propagator.AllDifferent.BC

  describe "Initial filtering" do
    test "cascading filtering" do
      ## all variables become fixed, and this will take a single filtering call.
      ##
      x_vars =
        Enum.map([{"x2", 1..2}, {"x1", 1}, {"x3", 1..3}, {"x4", 1..4}, {"x5", 1..5}], fn {name, d} ->
          Variable.new(d, name: name)
        end)

      bc_propagator = BC.new(x_vars)
      %{changes: changes} = Propagator.filter(bc_propagator)
      assert map_size(changes) == length(x_vars) - 1
      assert Enum.all?(Map.values(changes), fn change -> change == :fixed end)
      ## All variables are now fixed
      assert Enum.all?(x_vars, &Interface.fixed?/1)
    end

    test "inconsistency (pigeonhole)" do
      domains = List.duplicate(1..3, 4)

      vars =
        Enum.map(domains, fn d -> Variable.new(d) end)

      bc_propagator = BC.new(vars)
      assert Propagator.filter(bc_propagator) == :fail
    end
  end
end
