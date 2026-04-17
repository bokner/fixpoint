#
# Coins grid problem in Elixir.
#
# Problem from
# Tony Hurlimann: "A coin puzzle - SVOR-contest 2007"
# http://www.svor.ch/competitions/competition2007/AsroContestSolution.pdf
# """
# In a quadratic grid (or a larger chessboard) with 31x31 cells, one
# should place coins in such a way that the following conditions are
# fulfilled:
#   1. In each row exactly 14 coins must be placed.
#   2. In each column exactly 14 coins must be placed.
#   3. The sum of the quadratic horizontal distance from the main
#      diagonal of all cells containing a coin must be as small as possible.
#   4. In each cell at most one coin can be placed.
#
#  The description says to place 14x31 = 434 coins on the chessboard
#  each row containing 14 coins and each column also containing 14 coins.
# """
#
# Note: This problem is quite/very hard for (plain) CP solvers. A MIP solver solves
# the 14,31 problem in millis.
#
#
# Cf the MiniZinc model http://hakank.org/minizinc/coins_grid.mzn
#
#
# This program was created by Hakan Kjellerstrand, hakank@gmail.com
# See also my Elixir page: http://www.hakank.org/elxir/
#
## Boris Okner: modified to sync with the latest API,
## change naming and result handling.
##
defmodule CPSolver.Examples.Hakank.CoinsGrid do
  alias Hakank.CPUtils

  alias CPSolver.IntVariable
  alias CPSolver.Constraint.Sum
  # alias CPSolver.Constraint.Equal
  # alias CPSolver.Constraint.AllDifferent.FWC, as: AllDifferent
  alias CPSolver.Model
  alias CPSolver.Objective

  # import CPSolver.Constraint.Factory
  import CPSolver.Variable.View.Factory

  require Logger

  def run(opts \\ []) do
    run(31, 14, opts)
  end

  def run_7_3(opts) do
    run(7, 3, opts)
  end

  def run(n, c, opts \\ []) do
    Logger.configure(level: :info)
    opts =
      Keyword.merge(
      default_opts()
      |> Keyword.put(:solution_handler,
        fn solution -> print_solution(solution, n, false)
      end),
      opts
    )
    Logger.info("Started with n = #{n}, c = #{c}")
    # 7
    ##n =
    #  31

    # 3
    ##c =
    ##  14

    rs = 0..(n - 1)

    x =
      for i <- rs do
        for j <- rs do
          IntVariable.new(0..1, name: "x[#{i},#{j}]")
        end
      end

    x_flatten = List.flatten(x)

    # To be minimized
    z = IntVariable.new(0..(n * n * n), name: "z")

    # quadratic horizontal distance
    # MiniZinc: z = sum(i,j in 1..n) (  x[i,j]*(abs(i-j))*(abs(i-j))  )
    sum_constraint =
      Sum.new(
        z,
        for i <- rs, j <- rs do
          mul(CPUtils.mat_at(x, i, j), abs(i - j) ** 2)
        end
      )

    # MiniZinc: forall(i in 1..n) (  sum(j in 1..n) (x[i,j]) = c  )
    row_constraints =
      for row <- x do
        Sum.new(c, row)
      end

    # MiniZinc: forall(j in 1..n) (  sum(i in 1..n) (x[i,j]) = c  )
    col_constraints =
      for col <- CPUtils.transpose(x) do
        Sum.new(c, col)
      end

    # |> List.flatten
    constraints = [sum_constraint] ++ row_constraints ++ col_constraints
    # constraints = row_constraints ++ col_constraints

    model =
      Model.new(
        [z | x_flatten],
        constraints,
        # minimize z
        objective: Objective.minimize(z)
      )

    {:ok, res} =
      CPSolver.solve(
        model,
        opts)


    IO.inspect(res.statistics)
    best_solution = List.last(res.solutions)

    if best_solution do
      print_solution(best_solution, n, true)
    else
      Logger.info("No solutions found")
    end
  end

  defp print_solution(solution, n, print_matrix?) do
    solution = Enum.map(solution,
    fn {_name, value} ->
      value
      value when is_integer(value) -> value
    end)
    coins = hd(solution)
    matrix = tl(solution) |> Enum.take(n * n)
    Logger.info("coins: #{coins}")

    print_matrix? &&
      Enum.chunk_every(matrix, n)
      |> Enum.map(fn row -> Enum.join(row, " ") end)
      |> Enum.join("\n")
      |> then(fn matrix_str ->
        IO.puts("\nmatrix:\n" <> matrix_str <> "\n")
      end)
  end

  defp default_opts() do
      [
        n: 31, c: 14,
      search: {:first_fail, :indomain_max},
      #search: {:input_order, :indomain_max},
      # search: {:most_constrained, :indomain_max},
      # search: {:dom_deg, :indomain_max},
      # search: {:first_fail, :indomain_min},
      # search: {:max_regret, :indomain_max},
      #search: {:first_fail, :indomain_random},
      space_threads: 8,
      timeout: :timer.hours(1),
      # stop_on: {:max_solutions, 1},
    ]
  end
end
