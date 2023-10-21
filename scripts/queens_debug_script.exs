require Logger
alias CPSolver.Examples.Utils, as: ExamplesUtils
alias CPSolver.Examples.Queens, as: Queens
Logger.configure(level: :info)

nqueens = 5
expected_sols = 10
number_of_runs = 1000
trace_pattern = ["CPSolver.Space"]
solver_timeout = 1000


defmodule DebugQueens do
  def debug(nqueens, expected_sols, number_of_runs, trace_pattern, solver_timeout \\ 500) do


#trace_pattern = ["CPSolver.Space.create/_", "CPSolver.distribute/_", "CPsolver.Space.shutdown/_"]
result = Enum.reduce_while(1..number_of_runs, 0, fn i, succ ->
  Logger.info("##{i}")
  Replbug.start(trace_pattern, time: :timer.seconds(10), msgs: 100_000, max_queue: 100000, silent: true)
  Process.sleep(50)
  {:ok, solver} = Queens.solve(nqueens, solution_handler: ExamplesUtils.notify_client_handler())
  #Process.sleep(solver_timeout)
  ExamplesUtils.wait_for_solutions(expected_sols,
    solver_timeout,
    fn solution ->
      Queens.check_solution(solution) || Logger.error("Check failed on #{inspect solution}")
    end
  )

  Process.sleep(50)


  traces = Replbug.stop()
  CPSolver.statistics(solver).solution_count == expected_sols
  && {:cont, succ+1} || {:halt, %{solver: solver, traces: traces, successes: succ}}
end)
end
end


#result = DebugQueens.debug(nqueens, expected_sols, number_of_runs, trace_pattern, solver_timeout)

#trace_pattern = ["CPSolver.Space.handle_failure/1", "CPSolver.Space.handle_solved/1", "CPSolver.Space.distribute/_", "CPSolver.Space.branching/_", "CPSolver.Space.distribute/_", "CPSolver.Space.terminate/_"]
trace_pattern = ["CPSolver.Space", "CPSolver.Utils.localize_variables/_"]
result = DebugQueens.debug(nqueens, expected_sols, number_of_runs, trace_pattern, solver_timeout)


## Find the space that produced 'false positive'
solution_calls = result.traces |> Replbug.calls |> Map.get({CPSolver.Space, :solution, 1})
##
## Enum.map(solution_calls, fn c -> c.return end)
space_pid = fake_solution_call.caller_pid
fake_space_calls = result.traces |> Map.get(space_pid).finished_calls
## Create a timeline
timeline = Enum.sort_by(fake_space_calls, fn c -> c.call_timestamp end, Time) |> Enum.map(fn c -> {c.function, c.call_timestamp} end) |> Enum.reverse() |> Enum.reject(fn {func, ts} -> String.contains?(to_string(func), "-fun-") end)
