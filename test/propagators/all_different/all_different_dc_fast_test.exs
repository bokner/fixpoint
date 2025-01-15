defmodule CPSolverTest.Propagator.AllDifferent.DC.Fast do
  use ExUnit.Case

  alias CPSolver.ConstraintStore
  alias CPSolver.IntVariable, as: Variable
  alias CPSolver.Variable.Interface
  alias CPSolver.Propagator
  alias CPSolver.Propagator.AllDifferent.DC.Fast

  describe "Reduction algoritm" do
    test "reduction" do
        domains = [1, 1..2, 1..4, [1, 2, 4, 5]]
        vars = Enum.map(Enum.with_index(domains, 0), fn {d, idx} ->
          Variable.new(d, name: "x#{idx}")
        end)
        {value_graph, variable_vertices, value_vertices, partial_matching} = DC.build_value_graph(vars)
        matching = Kuhn.run(value_graph, variable_vertices, partial_matching)

        removal_callback = fn var_idx, value -> IO.inspect("Remove #{value} from x[#{var_idx}]") end
        reduced_graph =
          value_graph
          |> reduce(matching, variable_vertices, value_vertices, removal_callback)
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
