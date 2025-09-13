defmodule SudokuBenchmark do
  alias CPSolver.Examples.Sudoku
  alias CPSolver.Search.VariableSelector.{MostConstrained, FirstFail}
  alias CPSolver.Search.VariableSelector, as: Strategy
  require Logger

  def run(instance_file, n, space_threads, timeout, alldifferent_constraint) do
    instances = File.read!(instance_file) |> String.split("\n") |> Enum.take(n)

    Enum.map(
      instances |> Enum.with_index(1),
      fn {instance, idx} ->
        {:ok, res} =
          CPSolver.solve(Sudoku.model(instance, alldifferent_constraint: alldifferent_constraint),
            stop_on: {:max_solutions, 1},
            space_threads: space_threads,
            timeout: timeout,
            search: {
              Strategy.mixed([
                #Strategy.most_constrained(&Enum.random/1),
                #Strategy.first_fail(Strategy.most_constrained(&Enum.random/1)),
                #Strategy.afc({:afc_size_max, 0.9}, Strategy.first_fail(&Enum.random/1)),
                Strategy.dom_deg(&Enum.random/1),
                #Strategy.action({:action_size_min, 0.75}, Strategy.first_fail(&Enum.random/1)),
                #Strategy.action({:action_size_max, 0.9}, &Enum.random/1)
                # Strategy.chb(:chb_max, Strategy.first_fail(&Enum.random/1))
                # Strategy.most_completed(&Enum.random/1)
              ]),
              :indomain_random
            }
          )

        res
        |> tap(fn res -> IO.puts("#{idx}: #{div(res.statistics.elapsed_time, 1000)} ms") end)
      end
    )
  end

  def stats(instance_file, n, space_threads, timeout, alldiff) do
    run(instance_file, n, space_threads, timeout, alldiff)
    |> Enum.map(fn s ->
      !(s.solutions |> hd |> Sudoku.check_solution()) &&
        Logger.error("Wrong solution!")

      s.statistics.elapsed_time
    end)
    |> Enum.sort()
  end

  def benchmark() do
require Logger
alias CPSolver.Examples.Sudoku
alias CPSolver.Constraint.AllDifferent.{DC, BC, FWC, DC.Fast}

puzzle_file =

  "data/sudoku/clue17"
  #"data/sudoku/top95"
  #"data/sudoku/hardest"
  #"data/sudoku/puzzles5_forum_hardest_1905_11+"
  #"data/sudoku/quasi_uniform_834"
num_instances = 1_000
num_threads = 8
alldiff_impl = Fast

{elapsed_times, success_count, failure_count, incorrect_count} =
  SudokuBenchmark.run(puzzle_file, num_instances, num_threads, 30_000, alldiff_impl)
  |> Enum.with_index()
  |> Enum.reduce({[], 0, 0, 0}, fn {s, problem_num}, {elapsed_acc, succ_acc, fail_acc, wrong_acc} ->
    elapsed_acc = [s.statistics.elapsed_time | elapsed_acc]
    s.solutions
    |> List.first()
    |> then(fn sol ->
      if sol do
        if Sudoku.check_solution(sol) do
          #Logger.notice("OK")
          {elapsed_acc, succ_acc + 1, fail_acc, wrong_acc}
        else
          Logger.error("Wrong solution for #{problem_num} ! #{sol}")
           {elapsed_acc, succ_acc, fail_acc, wrong_acc + 1}
        end
      else
        Logger.error("No solution for #{problem_num}")
        {elapsed_acc, succ_acc, fail_acc + 1, wrong_acc}
      end
    end)
  end)
  #|> Enum.sort()
res = %{elapsed: elapsed_times, success: success_count, no_solution: failure_count, incorrect: incorrect_count}

Map.merge(res,
%{
  source: puzzle_file,
  shortest: Enum.min(res.elapsed),
  longest: Enum.max(res.elapsed),
  average: Enum.sum(res.elapsed) / length(res.elapsed),
  total: Enum.sum(res.elapsed),
  elapsed: Enum.sort(res.elapsed)
})
  end
end

# instance_file = "data/sudoku/clue17.txt"
# n = 100
# space_threads = 16
# timeout = :timer.seconds(30)
