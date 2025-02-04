defmodule CPSolverTest.Shared do
  use ExUnit.Case

  alias CPSolver.Shared

  test "space thread checkins/checkouts" do
    max_threads = 3
    shared = Shared.init_shared_data(space_threads: max_threads)
    ## No threads were checked out
    refute Shared.checkin_space_thread(shared)
    assert Enum.all?(1..max_threads, fn _ -> Shared.checkout_space_thread(shared) end)
    ## No more threads available
    refute Shared.checkout_space_thread(shared)
    ## Put them all back
    assert Enum.all?(1..max_threads, fn _ -> Shared.checkin_space_thread(shared) end)
    ## No more space for checkins
    refute Shared.checkin_space_thread(shared)
  end

  test "manage auxillaries" do
    shared = Shared.init_shared_data(space_threads: 4)
    refute Shared.get_auxillary(shared, :hello)
    assert Shared.put_auxillary(shared, :hello, "hello")
    assert "hello" == Shared.get_auxillary(shared, :hello)
  end
end
