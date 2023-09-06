defmodule CpSolverTest do
  use ExUnit.Case

  alias CPSolver.IntVariable
  alias CPSolver.Constraint.NotEqual

  test "Solves CSP with 2 variables and a single constraint" do
    x = IntVariable.new([1, 2])
    y = IntVariable.new([0, 1])

    model = %{
      variables: [x, y],
      constraints: [{NotEqual, x, y}]
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
    solver_state = :sys.get_state(solver)

    solutions =
      Enum.map(solver_state.solutions, fn solution ->
        Enum.map(solution, fn {_ref, value} -> value end)
      end)
      |> Enum.sort_by(fn [x, y] -> x + y end)

    assert solutions == [[1, 0], [2, 0], [2, 1]]
  end
end
