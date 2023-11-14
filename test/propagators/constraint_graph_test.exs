defmodule CPSolverTest.Propagator.ConstraintGraph do
  use ExUnit.Case
  require Logger

  describe "Propagator graph" do
    alias CPSolver.Propagator.ConstraintGraph
    alias CPSolver.Constraint.AllDifferent
    alias CPSolver.Constraint
    alias CPSolver.IntVariable, as: Variable

    test "Build graph from AllDifferent constraint" do
      graph = build_graph(AllDifferent, 3)
      ## Vertices: 3 propagators (x != y, y != z, x != z) and 3 variables
      assert length(Graph.vertices(graph)) == 6
      ## Edges: 2 per each propagator
      assert length(Graph.edges(graph)) == 6
      ## All edges are labeled with :fixed
      Enum.all?(Graph.edges(graph), fn edge -> assert edge.label == [:fixed] end)
    end

    test "Get propagators for the given variable and domain event" do
      graph = build_graph(AllDifferent, 3)

      variables =
        Graph.vertices(graph)
        |> Enum.flat_map(fn
          {:variable, v} -> [v]
          _ -> []
        end)

      ## For each variable, there are 2 propagators listening to ':fixed' domain change
      Enum.all?(variables, fn var_id ->
        assert length(ConstraintGraph.get_propagators(graph, var_id, :fixed)) == 2
      end)
    end

    test "Remove variables" do
      graph = build_graph(AllDifferent, 3)

      variables =
        [v1, _v2, _v3] =
        Graph.vertices(graph)
        |> Enum.flat_map(fn
          {:variable, v} -> [v]
          _ -> []
        end)

      assert graph |> ConstraintGraph.remove_variable(v1) |> Graph.edges() |> length == 4

      assert Enum.reduce(variables, graph, fn v, g ->
               assert Graph.vertices(g) != []
               ConstraintGraph.remove_variable(g, v)
             end)
             |> Graph.vertices() == []
    end

    defp build_graph(constraint_impl, n) do
      domain = 1..n
      variables = Enum.map(1..n, fn _ -> Variable.new(domain) end)
      constraint = {constraint_impl, variables}
      propagators = Constraint.constraint_to_propagators(constraint)
      ConstraintGraph.create(propagators)
    end
  end
end
