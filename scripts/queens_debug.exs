require Logger
alias CPSolver.Examples.Utils, as: ExamplesUtils
alias CPSolver.Examples.Queens, as: Queens
Logger.configure(level: :info)

nqueens = 3
expected_sols = 0
number_of_runs = 5000
trace_pattern = ["CPSolver.Space.Propagation.propagate/_", "CPSolver.Space", "CPSolver.Propagator.filter/_"]
solver_timeout = 100

defmodule DebugQueens do
  require Logger
  alias CPSolver.Examples.Utils, as: ExamplesUtils
  alias CPSolver.Examples.Queens, as: Queens
  Logger.configure(level: :info)

  def debug(nqueens, expected_sols, number_of_runs, trace_pattern, solver_timeout \\ 500) do
    result =
      Enum.reduce_while(1..number_of_runs, 0, fn i, succ ->
        Logger.info("##{i}")

        Replbug.start(trace_pattern,
          time: :timer.seconds(10),
          msgs: 100_000,
          max_queue: 100_000,
          silent: true
        )

        Process.sleep(50)

        {:ok, solver} =
          Queens.solve(nqueens, solution_handler: ExamplesUtils.notify_client_handler())

        # Process.sleep(solver_timeout)
        ExamplesUtils.wait_for_solutions(
          expected_sols,
          solver_timeout,
          fn solution ->
            Queens.check_solution(solution) ||
              Logger.error("Check failed on #{inspect(solution)}")
          end
        )

        Process.sleep(100)

        traces = Replbug.stop()

        (CPSolver.statistics(solver).solution_count == expected_sols &&
           {:cont, succ + 1}) || {:halt, %{solver: solver, traces: traces, successes: succ}}
      end)
  end

  ## Transcript for queens-3
  def transcript(result) do
    all_calls = Replbug.calls(result.traces)

    solved_space =
      Map.get(all_calls, {CPSolver.Space, :handle_solved, 1}) |> hd |> get_in([:caller_pid])

    ## Get all calls of "solved" space and sort in chronological order
    solved_space_calls =
      Map.get(result.traces, solved_space).finished_calls
      |> Enum.sort_by(fn c -> c.call_timestamp end, Time)

    Enum.each(solved_space_calls, fn c ->
      explain(c, %{result: result, space_calls: solved_space_calls, all_calls: all_calls})
    end)
  end

  def explain(call, data) do
    header(call)
    explain_call(call, data)
  end

  def explain_call(%{function: :init, module: CPSolver.Space, args: [arg]} = call, data) do
    variables = Map.get(arg, :variables)

    var_str =
      Enum.map_join(variables, "; ", fn v ->
        "#{v.name}: #{inspect(:gb_sets.to_list(v.domain))}"
      end)

    IO.puts("Variables: #{inspect(var_str)}")
    propagators = Map.get(arg, :propagators)
    propagator_str = Enum.map_join(propagators, "; ", fn p -> propagator_info(p) end)
    IO.puts("Propagators: #{inspect(propagator_str)}")
  end

  def explain_call(
        %{
          function: :propagate,
          module: CPSolver.Space.Propagation,
          args: [%MapSet{} = propagators | _]
        } = call,
        _
      ) do
    Logger.error("Propagate with ids")
  end

  def explain_call(
        %{
          function: :propagate,
          module: CPSolver.Space.Propagation,
          args: [propagators, _graph, caller_store],
          call_timestamp: start_ts,
          return_timestamp: end_ts
        } = call,
        %{all_calls: all_calls} = data
      )
      when is_map(propagators) do
    propagator_str = Enum.map_join(propagators, "; ", fn {_ref, p} -> propagator_info(p) end)
    Logger.notice("Propagating with: #{inspect(propagator_str)}")

    filter_calls =
      Enum.filter(
        all_calls |> Map.get({CPSolver.Propagator, :filter, 2}) |> Enum.sort_by(fn c -> c.call_timestamp end),
        fn %{args: [_p, opts]} = c ->
          c.function == :filter
            && Time.after?(c.call_timestamp, start_ts)
            && Time.before?(c.return_timestamp, end_ts)
            && caller_store == opts[:store]
        end
      )
    Logger.notice("Filtering: #{length(filter_calls)}")
    Enum.each(filter_calls, fn c -> explain(c, data) end)
  end

  def explain_call(%{function: :filter, module: CPSolver.Propagator, args: [p, opts], return: res} = call, _data) do
    Logger.notice("#{inspect propagator_info(p)} -> #{inspect res}")
  end

  def explain_call(call, _) do
    # Logger.error("-")
  end

  defp header(call) do
    Logger.info(
      "#{inspect(call.call_timestamp)}(#{inspect call.caller_pid}): #{call.module}.#{call.function}/#{length(call.args)}"
    )
  end

  defp propagator_info(%{mod: CPSolver.Propagator.NotEqual, args: [v1, v2, offset]} = propagator) do
    offset_str =
      case offset do
        0 -> ""
        n when n > 0 -> " + #{n}"
        n -> " #{n}"
      end

    "#{v1.name} != #{v2.name}#{offset_str}"
  end
end

# result = DebugQueens.debug(nqueens, expected_sols, number_of_runs, trace_pattern, solver_timeout)

# trace_pattern = ["CPSolver.Space.handle_failure/1", "CPSolver.Space.handle_solved/1", "CPSolver.Space.distribute/_", "CPSolver.Space.branching/_", "CPSolver.Space.distribute/_", "CPSolver.Space.terminate/_"]

# trace_pattern = ["CPSolver.Space", "CPSolver.Utils.localize_variables/_"]
# result = DebugQueens.debug(nqueens, expected_sols, number_of_runs, trace_pattern, solver_timeout)

## Find the space that produced 'false positive'
# solution_calls = result.traces |> Replbug.calls |> Map.get({CPSolver.Space, :solution, 1})
##
## Enum.map(solution_calls, fn c -> c.return end)

# space_pid = fake_solution_call.caller_pid
# fake_space_calls = result.traces |> Map.get(space_pid).finished_calls
## Create a timeline
# timeline = Enum.sort_by(fake_space_calls, fn c -> c.call_timestamp end, Time) |> Enum.map(fn c -> {c.function, c.call_timestamp} end) |> Enum.reverse() |> Enum.reject(fn {func, ts} -> String.contains?(to_string(func), "-fun-") end)
