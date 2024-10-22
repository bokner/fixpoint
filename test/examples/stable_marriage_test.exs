defmodule CPSolverTest.Examples.StableMarriage do
  use ExUnit.Case

  alias CPSolver.Examples.StableMarriage

  test "Instance: Van Hentenryck (OPL)" do

    {:ok, result} = CPSolver.solve(StableMarriage.model(:van_hentenryck))
    assert result.statistics.solution_count == 3
    assert Enum.all?(result.solutions,
      fn solution -> StableMarriage.check_solution(solution, :van_hentenryck)
    end)
  end
end
