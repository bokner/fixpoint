defmodule CPSolver.Examples.Queens do
  alias CPSolver.Constraint
  alias CPSolver.Constraint.AllDifferent.FWC, as: AllDifferent
  alias CPSolver.Constraint.Less
  alias CPSolver.IntVariable
  alias CPSolver.Model
  import CPSolver.Variable.View.Factory
  require Logger

  @queen_symbol "\u2655"

  def solve(n, solver_opts \\ []) when is_integer(n) do
    {:ok, _solver} =
      CPSolver.solve(model(n), solver_opts)
  end

  def model(n, symmetry_breaking_mode \\ nil) do
    range = 1..n
    ## Queen positions
    q = Enum.map(range, fn i -> IntVariable.new(range, name: "row #{i}") end)

    indexed_q = Enum.with_index(q, 1)

    diagonal_down = Enum.map(indexed_q, fn {var, idx} -> linear(var, 1, -idx) end)
    diagonal_up = Enum.map(indexed_q, fn {var, idx} -> linear(var, 1, idx) end)

    constraints =
      [
        Constraint.new(AllDifferent, diagonal_down),
        Constraint.new(AllDifferent, diagonal_up),
        Constraint.new(AllDifferent, q)
      ]

    # constraint alldifferent(q);
    # constraint alldifferent(i in 1..n)(q[i] + i);
    # constraint alldifferent(i in 1..n)(q[i] - i);
    ## left diagonal

    Model.new(
      Enum.map(inside_out_order(n), fn pos -> Enum.at(q, pos - 1) end),
      constraints ++ symmetry_breaking_constraints(q, symmetry_breaking_mode)
    )
  end

  def solve_and_print(nqueens, opts \\ [timeout: 1000]) do
    Logger.configure(level: :info)

    timeout = Keyword.get(opts, :timeout)

    {:ok, result} =
      CPSolver.solve_sync(model(nqueens, :half_symmetry),
        search: {:input_order, :indomain_random},
        stop_on: {:max_solutions, 1},
        timeout: timeout,
        space_threads: 4
      )

    case result.solutions do
      [] ->
        "No solutions found within #{timeout} milliseconds"

      [s | _rest] ->
        print_board(inside_out_to_normal(s))
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

    queens = inside_out_to_normal(queens)

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

  defp symmetry_breaking_constraints([q1, q2 | _] = _vars, :half_symmetry) do
    [Less.new(q1, q2)]
  end

  defp symmetry_breaking_constraints(_vars, _not_implemented) do
    []
  end

  def inside_out_order(n) do
    {_sign, order} =
      Enum.reduce(1..n, {1, [div(n, 2)]}, fn n, {direction_acc, acc} ->
        {-direction_acc, [hd(acc) + direction_acc * n | acc]}
      end)

    if rem(n, 2) == 1 do
      [n | tl(tl(order))]
    else
      tl(order)
    end
    |> Enum.reverse()
  end

  def inside_out_to_normal(queens) do
    Enum.map(Enum.zip(inside_out_order(length(queens)), queens) |> Enum.sort(), fn {_, p} -> p end)
  end
end
