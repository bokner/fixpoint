defmodule CPSolverTest.Examples.GraphColoring do
  use ExUnit.Case

  test "Triangle" do
    {:ok, solver} = CPSolver.Examples.GraphColoring.solve("data/graph_coloring/triangle")
    assert CPSolver.statistics(solver).solution_count == 6
  end

  test "Square" do
    {:ok, solver} = CPSolver.Examples.GraphColoring.solve("data/graph_coloring/square")
    assert CPSolver.statistics(solver).solution_count == 2
  end
end
