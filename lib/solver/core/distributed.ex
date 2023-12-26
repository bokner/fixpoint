defmodule CPSolver.Distributed do
  alias CPSolver.Shared

  def call(%{solver_pid: solver_pid} = solver, function, args \\ []) do
    :erpc.call(node(solver_pid), Shared, function, [solver, args])
  end
end
