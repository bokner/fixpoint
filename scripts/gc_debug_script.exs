Logger.configure(level: :error)

instance = "p4"
expected_sols = 2

number_of_runs = 50

#trace_pattern = ["CPSolver.Space.create/_", "CPSolver.distribute/_", "CPsolver.Space.shutdown/_"]
trace_pattern = ["CPSolver.Space"]
result = Enum.reduce_while(1..number_of_runs, 0, fn i, succ ->
  Replbug.start(trace_pattern, time: :timer.seconds(10), msgs: 100_000, silent: true)
  Process.sleep(100)
  {:ok, solver} = CPSolver.Examples.GraphColoring.solve("data/graph_coloring/#{instance}")
  Process.sleep(500)
  traces = Replbug.stop()
  Process.sleep(100)
  CPSolver.statistics(solver).solution_count == expected_sols && {:cont, succ+1} || {:halt, %{solver: solver, traces: traces, successes: succ}}
end)
