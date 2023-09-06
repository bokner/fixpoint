defmodule CPSolverTest.Examples.GraphColoring do
  use ExUnit.Case

  test "P3" do
    test_graph("p3", 2)
  end

  test "P4" do
    test_graph("p4", 2)
  end

  test "Triangle" do
    test_graph("triangle", 6)
  end

  test "Square" do
    test_graph("square", 2)
  end

  test "Triangle and edge" do
    test_graph("paw", 12, 100)
  end

  defp test_graph(graph_name, expected_solutions, timeout \\ 20) do
    {:ok, solver} = CPSolver.Examples.GraphColoring.solve("data/graph_coloring/#{graph_name}")
    Process.sleep(timeout)
    assert CPSolver.statistics(solver).solution_count == expected_solutions
  end
end
