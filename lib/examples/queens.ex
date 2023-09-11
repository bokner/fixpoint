defmodule CPSolver.Examples.Queens do
  alias CPSolver.Constraint.NotEqual
  alias CPSolver.IntVariable

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

  def solve_and_print(nqueens) do
    Logger.configure(level: :error)

    solve(nqueens, stop_on: {:max_solutions, 1})
    |> tap(fn {:ok, solver} ->
      Process.sleep(2000)
      IO.puts(print_board(hd(CPSolver.solutions(solver))))
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
                do: IO.ANSI.white() <> @queen_symbol,
                else: IO.ANSI.light_blue() <> "."
            end,
            " "
          )
        end,
        "\n"
      ) <> "\n"
  end
end
