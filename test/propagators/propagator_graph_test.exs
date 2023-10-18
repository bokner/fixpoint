defmodule CPSolverTest.Propagator.ConstraintGraph do
  use ExUnit.Case

  describe "Propagator graph" do
    alias CPSolver.Propagator.ConstraintGraph
    alias CPSolver.Constraint.AllDifferent
    alias CPSolver.Constraint
    alias CPSolver.IntVariable, as: Variable

    test "Build graph from AllDifferent constraint" do
      domain = 1..3
      variables = Enum.map(1..3, fn _ -> Variable.new(domain) end)
      constraint = {AllDifferent, variables}
      propagators = Constraint.constraint_to_propagators(constraint)

      graph = ConstraintGraph.create(propagators)
      ## Vertices: 3 propagators (x != y, y != z, x != z) and 3 variables
      assert length(Graph.vertices(graph)) == 6
      ## Edges: 2 per each propagator
      assert length(Graph.edges(graph)) == 6
      ## All edges are labeled with :fixed
      Enum.all?(Graph.edges(graph), fn edge -> assert edge.label == :fixed end)
    end
  end
end
