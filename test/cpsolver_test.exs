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

    target_pid = self()

    solution_handler = fn solution ->
      send(target_pid, Enum.sort_by(solution, fn {var, _value} -> var end))
    end

    {:ok, solver} = CPSolver.solve(model, solution_handler: solution_handler)

    Process.sleep(10)

    solutions =
      Enum.map(1..3, fn _ ->
        receive do
          sol -> sol
        end
      end)

    # Only 3 solutions
    refute_receive _msg, 100

    # For all solutions, constraints (x != y and y != z) are satisfied.
    assert Enum.all?(solutions, fn variables ->
             [x, y] = Enum.map(variables, fn {_id, value} -> value end)
             x != y
           end)

    ## Solution, failure and node count from solver state.
    assert CPSolver.statistics(solver).solution_count == length(solutions)
    ## NotEqual never results in failures, unless started with initially
    ## inconsistent domains.
    assert CPSolver.statistics(solver).failure_count == 0
    ## Note: there are 2 "first fail" distributions:
    ## 1. Variable 'x' triggers distribution into 2 spaces - (x: 1, y: [0, 1]) and (x: 2, y: [0, 1])).
    ## 2. First space produces solution (x: 1, y: 0)
    ## 3. Second space triggers distribution into 2 spaces - (x: 2, y: 0) and (x: 2, y: 1)
    ## 4. These 2 spaces produce remaining solutions.
    ## 5. There have been 5 spaces - top one, and 4 as described above, which corresponds
    ## to 5 nodes.
    assert CPSolver.statistics(solver).node_count == 5
  end
end
