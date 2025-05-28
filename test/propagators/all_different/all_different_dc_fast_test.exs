defmodule CPSolverTest.Propagator.AllDifferent.DC.Fast do
  use ExUnit.Case

  # alias CPSolver.ConstraintStore
  alias CPSolver.IntVariable, as: Variable
  alias CPSolver.Variable.Interface
  # alias CPSolver.Propagator
  alias CPSolver.Propagator.AllDifferent.DC.Fast

  describe "Reduction algoritm (Zhang et al. paper example" do
    test "reduction" do
      domains = [1, 1..2, 1..4, [1, 2, 4, 5]]

      [_x0, x1, x2, x3] =
        vars =
        Enum.map(Enum.with_index(domains, 0), fn {d, idx} ->
          Variable.new(d, name: "x#{idx}")
        end)

      state = Fast.initial_reduction(vars)
      reduced_value_graph = state[:value_graph]

      assert Interface.fixed?(x1) && Interface.min(x1) == 2
      assert Interface.min(x2) == 3 && Interface.max(x2) == 4
      assert Interface.min(x3) == 4 && Interface.max(x3) == 5

      ## Reduced value graph consists of 3 components, as per paper
      assert 3 == length(BitGraph.Algorithms.components(reduced_value_graph))

      assert 6 == length(BitGraph.edges(reduced_value_graph))
      assert 9 == MapSet.size(BitGraph.vertices(reduced_value_graph))

      # The value graph is split into 2 single-edge components and one component with Γ(A) + A vertices
      assert Enum.map(BitGraph.Algorithms.components(reduced_value_graph), fn component -> MapSet.size(component) end) |> Enum.sort() == [2, 2, 5]
      # Single-edge SCCs are removed, one left is the one with reduced t1-type edges
      assert length(state.sccs) == 0
      assert length(state.type1_components) == 1
    end

    test "cascading" do
      [x2, _x1, x3, x4, x5] =
        vars =
        Enum.map([{"x2", 1..2}, {"x1", 1}, {"x3", 1..3}, {"x4", 1..4}, {"x5", 1..5}], fn {name, d} ->
          Variable.new(d, name: name)
        end)

      Fast.initial_reduction(vars)
      ## all variables are fixed
      assert Interface.fixed?(x2) && Interface.min(x2) == 2
      assert Interface.fixed?(x3) && Interface.min(x3) == 3
      assert Interface.fixed?(x4) && Interface.min(x4) == 4
      assert Interface.fixed?(x5) && Interface.min(x5) == 5
    end

    test "inconsistency (pigeonhole)" do
      domains = List.duplicate(1..3, 4)

      vars =
        Enum.map(domains, fn d -> Variable.new(d) end)

      assert catch_throw(Fast.initial_reduction(vars)) == :fail
    end
  end

  describe "Filtering" do
    alias CPSolver.Propagator
    test "reduction" do
      domains = [1, 1..2, 1..4, [1, 2, 4, 5]]

      [_x0, x1, x2, x3] =
        vars =
        Enum.map(Enum.with_index(domains, 0), fn {d, idx} ->
          Variable.new(d, name: "x#{idx}")
        end)

      dc_propagator = Propagator.new(Fast, vars)
      %{active?: true, state: state1} =
        Propagator.filter(dc_propagator)
      ## Variable filtering
      assert Interface.fixed?(x1) && Interface.min(x1) == 2
      assert Interface.min(x2) == 3 && Interface.max(x2) == 4
      assert Interface.min(x3) == 4 && Interface.max(x3) == 5

      ## More filtering
      domain_change = Interface.fix(x2, 4)

      assert %{active?: false} =
        Propagator.filter(Map.put(dc_propagator, :state, state1), changes: %{2 => domain_change})

      assert Interface.fixed?(x2) && Interface.min(x2) == 4
      assert Interface.fixed?(x3) && Interface.min(x3) == 5

    end
  end
end
