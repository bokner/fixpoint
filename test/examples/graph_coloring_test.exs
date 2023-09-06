defmodule CPSolverTest.Examples.GraphColoring do
  use ExUnit.Case

  test "P3" do
    {:ok, solver} = CPSolver.Examples.GraphColoring.solve("data/graph_coloring/p3")
    Process.sleep(10)
    assert CPSolver.statistics(solver).solution_count == 2
  end

  test "Triangle" do
    {:ok, solver} = CPSolver.Examples.GraphColoring.solve("data/graph_coloring/triangle")
    Process.sleep(10)
    assert CPSolver.statistics(solver).solution_count == 6
  end

  test "Square" do
    {:ok, solver} = CPSolver.Examples.GraphColoring.solve("data/graph_coloring/square")
    Process.sleep(10)
    assert CPSolver.statistics(solver).solution_count == 2
  end

  test "Triangle and edge" do
    {:ok, solver} = CPSolver.Examples.GraphColoring.solve("data/graph_coloring/triangle_uni")
    Process.sleep(100)
    assert CPSolver.statistics(solver).solution_count == 12
  end
end
