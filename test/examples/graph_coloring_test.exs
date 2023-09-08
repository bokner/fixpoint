defmodule CPSolverTest.Examples.GraphColoring do
  use ExUnit.Case, async: false

  test "P3" do
    test_graph("p3", 2, trials: 10)
  end

  test "P4" do
    test_graph("p4", 2, trials: 10)
  end

  test "Triangle" do
    test_graph("triangle", 6, trials: 10)
  end

  test "Square" do
    test_graph("square", 2, trials: 10)
  end

  test "Paw" do
    test_graph("paw", 12, timeout: 100, trials: 10)
  end

  test "gc_15_30_3" do
    test_graph("gc_15_30_3", 12, timeout: 1000, trials: 5)
  end

  test "Multiple P4 runs" do
    test_graph("p4", 2, trials: 20)
  end

  test "Multiple P3 runs" do
    test_graph("p3", 2, trials: 20)
  end

  defp test_graph(graph_name, expected_solutions, opts \\ []) do
    opts = Keyword.merge([timeout: 100, trials: 1], opts)
    instance = "data/graph_coloring/#{graph_name}"

    Enum.each(1..opts[:trials], fn _ ->
      {:ok, solver} = CPSolver.Examples.GraphColoring.solve(instance)
      Process.sleep(opts[:timeout])

      assert Enum.all?(CPSolver.solutions(solver), fn solution ->
               CPSolver.Examples.GraphColoring.check_solution(solution, instance)
             end)

      assert CPSolver.statistics(solver).solution_count == expected_solutions
    end)
  end
end
