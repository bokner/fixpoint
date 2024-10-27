defmodule CPSolverTest.Examples.Zebra do
  use ExUnit.Case

  alias CPSolver.Examples.Zebra

  test "proper solution" do
    {:ok, result} = CPSolver.solve(Zebra.model())
    ## Check against known solution
    assert  %{zebra_owner: :japanese, water_drinker: :norwegian} = Zebra.puzzle_solution(result)
  end
end
