defmodule CPSolverTest.Examples.Reindeers do
  use ExUnit.Case

  alias CPSolver.Examples.Reindeers

  test "order" do
    order = [Dancer, Donder, Comet, Vixen, Blitzen, Dasher, Rudolph, Cupid, Prancer]

    {:ok, result} = CPSolver.solve(Reindeers.model())

    positions = hd(result.solutions)

    solution_order =
      Enum.zip(result.variables, positions)
      |> Enum.sort_by(fn {_name, pos} -> pos end)
      |> Enum.map(fn {name, _pos} -> name end)

    assert order == solution_order
  end
end
