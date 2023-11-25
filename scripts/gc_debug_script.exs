require Logger
Logger.configure(level: :error)

instance = "p3"
expected_sols = 2
number_of_runs = 50
trace_pattern = ["CPSolver.Space"]
solver_timeout = 1000

defmodule DebugGC do
  def debug(instance, expected_sols, number_of_runs, trace_pattern, solver_timeout \\ 500) do
    # trace_pattern = ["CPSolver.Space.create/_", "CPSolver.distribute/_", "CPsolver.Space.shutdown/_"]
    result =
      Enum.reduce_while(1..number_of_runs, 0, fn i, succ ->
        # Replbug.start(trace_pattern, time: :timer.seconds(10), msgs: 100_000, max_queue: 10000, silent: true)
        Process.sleep(100)
        {:ok, solver} = CPSolver.Examples.GraphColoring.solve("data/graph_coloring/#{instance}")
        Process.sleep(solver_timeout)
        traces = Replbug.stop()
        Process.sleep(100)

        (CPSolver.statistics(solver).solution_count == expected_sols &&
           {:cont, succ + 1}) || {:halt, %{solver: solver, traces: traces, successes: succ}}
      end)
  end
end

if result.successes == number_of_runs do
  Logger.info("All good")
  # else
  #  space_pids = Map.keresult.traces
end
