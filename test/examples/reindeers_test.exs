defmodule CPSolverTest.Examples.Reindeers do
  use ExUnit.Case

  alias CPSolver.Examples.Reindeers

  test "order" do
    order = [Dancer, Donder, Comet, Vixen, Blitzen, Dasher, Rudolph, Cupid, Prancer]
    pid = self()

    {:ok, _solver} =
      Reindeers.solve(
        solution_handler: fn sol ->
          send(
            pid,
            sol
            |> Enum.sort_by(fn {_name, pos} -> pos end)
            |> Enum.map(fn {name, _pos} -> name end)
          )
        end
      )

    assert_receive ^order, 100
  end
end
