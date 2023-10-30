defmodule CpSolverTest do
  use ExUnit.Case

  alias CPSolver.IntVariable
  alias CPSolver.Constraint.NotEqual
  alias CPSolver.Examples.Queens

  test "Solves CSP with 2 variables and a single constraint" do
    x = IntVariable.new([1, 2])
    y = IntVariable.new([0, 1])

    model = %{
      variables: [x, y],
      constraints: [NotEqual.new(x, y)]
    }

    {:ok, solver} = CPSolver.solve(model)

    Process.sleep(100)

    assert CPSolver.statistics(solver).failure_count == 0
    ## Note: there are 2 "first fail" distributions:
    ## 1. Variable 'x' triggers distribution into 2 spaces - (x: 1, y: [0, 1]) and (x: 2, y: [0, 1])).
    ## 2. First space produces solution (x: 1, y: 0)
    ## 3. Second space triggers distribution into 2 spaces - (x: 2, y: 0) and (x: 2, y: 1)
    ## 4. These 2 spaces produce remaining solutions.
    ## 5. There have been 5 spaces - top one, and 4 as described above, which corresponds
    ## to 5 nodes.
    assert CPSolver.statistics(solver).node_count == 5
    assert CPSolver.statistics(solver).solution_count == 3

    solutions =
      solver
      |> CPSolver.solutions()
      |> Enum.sort_by(fn [x, y] -> x + y end)

    assert solutions == [[1, 0], [2, 0], [2, 1]]
  end

  test "Stops on max_solutions reached" do
    max_solutions = 2
    {:ok, solver} = Queens.solve(5, stop_on: {:max_solutions, max_solutions})
    Process.sleep(100)
    assert CPSolver.complete?(solver)
    ## TODO: this assertion will be relevant with sync solving.
    # assert CPSolver.statistics(solver).solution_count == max_solutions
  end

  test "Synchronous solver" do
    {:ok, result} = CPSolver.solve_sync(Queens.model(8))
    assert result.statistics.solution_count == 92
    ## No active nodes - solving is done
    assert result.statistics.active_node_count == 0
  end
end
