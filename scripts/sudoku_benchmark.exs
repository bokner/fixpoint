defmodule SudokuBenchmark do
  alias CPSolver.Examples.Sudoku

  require Logger

  def run(instance_file, n, space_threads, timeout) do
    instances = File.read!(instance_file) |> String.split("\n") |> Enum.take(n)

    Enum.map(
      instances |> Enum.with_index(1),
      fn {instance, idx} ->
        {:ok, res} =
          CPSolver.solve_sync(Sudoku.model(instance),
            stop_on: {:max_solutions, 1},
            max_space_threads: space_threads,
            timeout: timeout,
            search: {:first_fail, :indomain_random}
          )

        res
        |> tap(fn res -> IO.puts("#{idx}: #{div(res.statistics.elapsed_time, 1000)} ms") end)
      end
    )
  end

  def stats(instance_file, n, space_threads, timeout) do
    run(instance_file, n, space_threads, timeout)
    |> Enum.map(fn s ->
      !(s.solutions |> hd |> Sudoku.check_solution()) &&
        Logger.error("Wrong solution!")

      s.statistics.elapsed_time
    end)
    |> Enum.sort()
  end
end

instance_file = "data/sudoku/clue17.txt"
n = 100
space_threads = 16
timeout = :timer.seconds(30)
