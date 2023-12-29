defmodule CPSolverTest.Distributed do
  use ExUnit.Case
  alias CPSolver.Examples.Sudoku

  setup do
    # {:ok, spawned} = ExUnited.spawn([:test_worker1, :test_worker2, :test_worker3])
    :ok = LocalCluster.start()

    spawned = LocalCluster.start_nodes(:spawn, 2)

    on_exit(fn ->
      LocalCluster.stop()
    end)

    :ok
  end

  test "distributed solving uses cluster nodes assigned to it" do
    # Run the solver with the model that takes noticeable time to complete.
    difficult_sudoku = Sudoku.puzzles().s9x9_clue17_hard
    {:ok, solver} = CPSolver.solve(Sudoku.model(difficult_sudoku), distributed: Node.list())
    # Wait for a bit so all nodes get involved into solving.
    Process.sleep(500)
    # Collect active spaces and group them by the nodes.
    spaces = CPSolver.Shared.active_nodes(solver)
    spaces_by_node = Enum.group_by(spaces, fn s -> node(s) end)
    ## All nodes participated in the solving
    assert Map.keys(spaces_by_node) |> Enum.sort() == Node.list() |> Enum.sort()
  end
end
