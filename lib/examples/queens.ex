defmodule CPSolver.Examples.Queens do
  alias CPSolver.Constraint.NotEqual
  alias CPSolver.IntVariable

  alias CPSolver.Examples.Utils, as: ExamplesUtils

  require Logger
  @queen_symbol "\u2655"

  def solve(n, solver_opts \\ []) when is_integer(n) do
    range = 1..n
    ## Queen positions
    q = Enum.map(range, fn _ -> IntVariable.new(range) end)

    constraints =
      for i <- 0..(n - 2) do
        for j <- (i + 1)..(n - 1) do
          # queens q[i] and q[i] not on ...
          [
            ## ... the same line
            {NotEqual, Enum.at(q, i), Enum.at(q, j), 0},
            ## ... the same left diagonal
            {NotEqual, Enum.at(q, i), Enum.at(q, j), i - j},
            ## ... the same right diagonal
            {NotEqual, Enum.at(q, i), Enum.at(q, j), j - i}
          ]
        end
      end
      |> List.flatten()

    model = %{
      variables: q,
      constraints: constraints
    }

    {:ok, _solver} =
      CPSolver.solve(model, solver_opts)
  end

  def solve_and_print(nqueens, opts \\ [timeout: 1000]) do
    Logger.configure(level: :info)

    timeout = Keyword.get(opts, :timeout)
    ExamplesUtils.flush_solutions()

    solve(nqueens,
      solution_handler: ExamplesUtils.notify_client_handler(),
      stop_on: {:max_solutions, 1}
    )
    |> tap(fn {:ok, _solver} ->
      ExamplesUtils.wait_for_solution(
        timeout,
        fn solution ->
          check_solution(solution)
          |> tap(fn _ -> IO.puts(print_board(solution)) end)
        end
      )
    end)
  end

  def print_board(queens) do
    n = length(queens)

    "\n" <>
      Enum.join(
        for i <- 1..n do
          Enum.join(
            for j <- 1..n do
              if Enum.at(queens, i - 1) == j,
                do: IO.ANSI.red() <> @queen_symbol,
                else: IO.ANSI.light_blue() <> "."
            end,
            " "
          )
        end,
        "\n"
      ) <> "\n"
  end

  def check_solution(queens) do
    n = length(queens)

    Enum.all?(0..(n - 2), fn i ->
      Enum.all?((i + 1)..(n - 1), fn j ->
        # queens q[i] and q[i] not on ...
        ## ... the same line
        ## ... the same left or right diagonal
        (Enum.at(queens, i) != Enum.at(queens, j))
        |> tap(fn res -> !res && Logger.error("Queens #{i} and #{j} : same-line violation") end) &&
          (abs(Enum.at(queens, i) - Enum.at(queens, j)) != j - i)
          |> tap(fn res ->
            !res && Logger.error("Queens #{i} and #{j} : same-diagonal violation")
          end)
      end)
    end)
  end
end
