defmodule CPSolver.Examples.Queens do
  alias CPSolver.Constraint.NotEqual
  alias CPSolver.IntVariable
  require Logger
  @queen_symbol "\u2655"

  def solve(n, solver_opts \\ []) when is_integer(n) do
    {:ok, _solver} =
      CPSolver.solve(model(n), solver_opts)
  end

  def model(n) do
    range = 1..n
    ## Queen positions
    q =
      Enum.map(Enum.with_index(range, 1), fn {_, idx} ->
        IntVariable.new(range, name: "row #{idx}")
      end)

    constraints =
      for i <- 0..(n - 2) do
        for j <- (i + 1)..(n - 1) do
          # queens q[i] and q[i] not on ...
          [
            ## ... the same row
            NotEqual.new(Enum.at(q, i), Enum.at(q, j), 0),
            ## ... the same left diagonal
            NotEqual.new(Enum.at(q, i), Enum.at(q, j), i - j),
            ## ... the same right diagonal
            NotEqual.new(Enum.at(q, i), Enum.at(q, j), j - i)
          ]
        end
      end
      |> List.flatten()

    %{
      variables: q,
      constraints: constraints
    }
  end

  def solve_and_print(nqueens, opts \\ [timeout: 1000]) do
    Logger.configure(level: :info)

    timeout = Keyword.get(opts, :timeout)

    {:ok, result} =
      CPSolver.solve_sync(model(nqueens),
        stop_on: {:max_solutions, 1},
        timeout: timeout
      )

    case result.solutions do
      [] ->
        "No solutions found within #{timeout} milliseconds"

      [s | _rest] ->
        print_board(s)
        |> tap(fn _ -> check_solution(s) && Logger.notice("Solution checked!") end)
    end

    {:ok, result}
  end

  def print_board(queens) do
    n = length(queens)

    ("\n" <>
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
       ) <> "\n")
    |> IO.puts()
  end

  def check_solution(queens) do
    n = length(queens)

    Enum.all?(0..(n - 2), fn i ->
      Enum.all?((i + 1)..(n - 1), fn j ->
        # queens q[i] and q[i] not on ...
        ## ... the same line
        ## ... the same left or right diagonal
        (Enum.at(queens, i) != Enum.at(queens, j))
        |> tap(fn res ->
          !res && Logger.error("Queens #{i + 1} and #{j + 1} : same-line violation")
        end) &&
          (abs(Enum.at(queens, i) - Enum.at(queens, j)) != j - i)
          |> tap(fn res ->
            !res && Logger.error("Queens #{i + 1} and #{j + 1} : same-diagonal violation")
          end)
      end)
    end)
  end
end
