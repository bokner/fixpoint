defmodule CPSolverTest.Examples.GraphColoring do
  use ExUnit.Case, async: false

  alias CPSolver.Examples.GraphColoring
  alias CPSolver.Examples.Utils, as: ExamplesUtils

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

  test "Petersen" do
    test_graph("petersen", 120, timeout: 500, trials: 5)
  end

  test "gc_15_30_1" do
    test_graph("gc_15_30_1", 36, timeout: 500, trials: 5)
  end

  test "gc_15_30_3" do
    test_graph("gc_15_30_3", 12, timeout: 500, trials: 5)
  end

  test "Multiple P4 runs" do
    test_graph("p4", 2, trials: 20)
  end

  test "Multiple P3 runs" do
    test_graph("p3", 2, trials: 20)
  end

  defp test_graph(graph_name, expected_solutions, opts \\ []) do
    opts =
      Keyword.merge([timeout: 100, trials: 1], opts)
      |> Keyword.put(:solution_handler, ExamplesUtils.notify_client_handler())

    instance = "data/graph_coloring/#{graph_name}"

    Enum.each(1..opts[:trials], fn _ ->
      ExamplesUtils.flush_solutions()
      {:ok, solver} = GraphColoring.solve(instance)

      ExamplesUtils.wait_for_solutions(expected_solutions, opts[:timeout], fn solution ->
        assert_solution(solution, instance)
      end)

      assert CPSolver.statistics(solver).solution_count == expected_solutions
    end)
  end

  defp assert_solution(solution, instance) do
    assert GraphColoring.check_solution(solution, instance)
  end
end
