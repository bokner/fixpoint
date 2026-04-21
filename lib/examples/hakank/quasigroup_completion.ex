#
# Quasigroup Completion in Elixir.
#
# See
# Carla P. Gomes and David Shmoys:
# "Completing Quasigroups or Latin Squares: Structured Graph Coloring Problem"
#
# See also
# Ivars Peterson "Completing Latin Squares"
# http://www.maa.org/mathland/mathtrek_5_8_00.html
# """
# Using only the numbers 1, 2, 3, and 4, arrange four sets of these
# numbers into a four-by-four array so that no column or row contains
# the same two numbers. The result is known as a Latin square.
# ...
# The so-called quasigroup completion problem concerns a table that is
# correctly but only partially filled in. The question is whether the
# remaining blanks in the table can be filled in to obtain a complete
# Latin square (or a proper quasigroup multiplication table).
# """
#
#
# This program was created by Hakan Kjellerstrand, hakank@gmail.com
# See also my Elixir page: http://www.hakank.org/elxir/
#
## Boris Okner: modified to sync with the latest API,
## change then naming and the result handling.
##

defmodule CPSolver.Examples.Hakank.QuasigroupCompletion do
  import Hakank.CPUtils

  alias CPSolver.IntVariable
  # alias CPSolver.Constraint.Sum
  # alias CPSolver.Constraint.Equal
  # alias CPSolver.Constraint.AllDifferent.FWC, as: AllDifferent
  alias CPSolver.Model

  #
  # Example from Ruben Martins and Inès Lynce
  # Breaking Local Symmetries in Quasigroup Completion Problems, page 3
  # The solution is unique:
  # 1 3 2 5 4
  # 2 5 4 1 3
  # 4 1 3 2 5
  # 5 4 1 3 2
  # 3 2 5 4 1
  #
  def puzzle(1) do
    [[1, 0, 0, 0, 4],   # 0 are the unknowns
     [0, 5, 0, 0, 0],
     [4, 0, 0, 2, 0],
     [0, 4, 0, 0, 0],
     [0, 0, 5, 0, 1]]
  end

  #
  # Example from Gomes & Shmoys, page 3.
  # Solution:
  # 4 1 2 3
  # 2 3 4 1
  # 1 4 3 2
  # 3 2 1 4
  #
  def puzzle(2) do
    [[0, 1, 2, 3],
     [2, 0, 4, 1],
     [1, 4, 0, 2],
     [3, 0, 1, 0]]
  end

  # Example from Gomes & Shmoys, page 7
  # Two solutions.
  #
  def puzzle(3) do
    [[0, 1, 0, 0],
     [0, 0, 2, 0],
     [0, 3, 0, 0],
     [0, 0, 0, 4]]
  end


  #
  # Example from Global Constraint Catalogue
  # http://www.emn.fr/x-info/sdemasse/gccat/sec2.7.108.html
  #
  # 12 solutions.
  #
  def puzzle(4) do
    [[1, 0, 0, 0],
     [0, 0, 0, 3],
     [3, 0, 0, 0],
     [0, 0, 0, 1]]
  end


  #
  # Problem from http://www.cs.cornell.edu/gomes/QUASIdemo.html
  # (n = 10]
  # Pattern #1.
  # There are _many_ solutions to this problem.
  #
  def puzzle(5) do
    [
      [0, 0, 0, 1, 0, 0, 0, 0, 0, 0],
      [0, 0, 1, 0, 0, 0, 0, 0, 0, 0],
      [0, 1, 0, 0, 0, 2, 0, 0, 0, 0],
      [1, 0, 0, 0, 2, 0, 0, 0, 0, 0],
      [0, 0, 0, 2, 1, 0, 0, 0, 0, 0],
      [0, 0, 2, 0, 0, 1, 0, 0, 0, 0],
      [0, 0, 0, 0, 0, 0, 1, 0, 0, 0],
      [0, 0, 0, 0, 0, 0, 0, 1, 0, 2],
      [0, 0, 0, 0, 0, 0, 0, 0, 2, 0],
      [0, 0, 0, 0, 0, 0, 0, 2, 0, 0]
    ]
  end

  #
  # Problem from http://www.cs.cornell.edu/gomes/QUASIdemo.html
  # (n = 10]
  # Pattern #2.
  # There are many solutions to this problem.
  #
  def puzzle(6) do
    [
      [0, 0, 1, 2, 3, 4, 0, 0, 0, 0],
      [0, 1, 2, 3, 0, 0, 4, 0, 0, 0],
      [1, 2, 3, 0, 0, 0, 0, 4, 0, 0],
      [2, 3, 0, 0, 0, 0, 0, 0, 4, 0],
      [3, 0, 0, 0, 0, 0, 0, 0, 0, 4],
      [5, 6, 0, 0, 0, 0, 0, 0, 0, 0],
      [0, 5, 6, 0, 0, 0, 0, 0, 0, 0],
      [0, 0, 5, 6, 0, 0, 0, 0, 0, 0],
      [0, 0, 0, 5, 6, 0, 0, 0, 0, 0],
      [0, 0, 0, 0, 5, 6, 0, 0, 0, 0]
    ]
  end

  #
  # Problem from http://www.cs.cornell.edu/gomes/QUASIdemo.html
  # (n = 10]
  # Pattern #3.
  # Coding:
  #    dark red   = 1
  #    light blue = 2
  #    dark blue  = 3
  #    light red  = 4
  #    brown      = 5
  #    green      = 6
  #    pink       = 7
  #    grey       = 8
  #    black      = 9
  #    yellow     = 10
  # There are 40944 solutions for this pattern.
  #
  # This takes 9.5s, about to solve and print all solutions.
  #
  def puzzle(7) do
    [
      [0, 0, 1, 5, 2, 6, 7, 8, 0, 0],
      [0, 1, 5, 2, 0, 0, 6, 7, 8, 0],
      [1, 5, 2, 0, 0, 0, 0, 6, 7, 8],
      [5, 2, 0, 0, 0, 0, 0, 0, 6, 7],
      [2, 0, 0, 0, 0, 0, 0, 0, 0, 6],
      [4, 10, 0, 0, 0, 0, 0, 0, 3, 9],
      [0, 4, 10, 0, 0, 0, 0, 3, 9, 0],
      [0, 0, 4, 10, 0, 0, 3, 9, 0, 0],
      [0, 0, 0, 4, 10, 3, 9, 0, 0, 0],
      [0, 0, 0, 0, 4, 9, 0, 0, 0, 0]
    ]
  end

  #
  # Problem from http://www.cs.cornell.edu/gomes/QUASIdemo.html
  # (n = 10]
  # Pattern #4.
  #  dark red   = 1
  #  light blue = 2
  #  dark blue  = 3
  #  light red  = 4
  # Note: There are no solutions to this problem.
  #
  def puzzle(8) do
    [
      [1, 0, 0, 0, 0, 0, 0, 0, 0, 0],
      [2, 1, 0, 0, 0, 0, 0, 0, 0, 4],
      [3, 2, 1, 0, 0, 0, 0, 0, 4, 0],
      [0, 3, 2, 1, 0, 0, 0, 4, 0, 0],
      [0, 0, 3, 2, 1, 0, 4, 0, 0, 0],
      [0, 0, 0, 3, 2, 1, 0, 0, 0, 0],
      [0, 0, 0, 0, 3, 2, 1, 0, 0, 0],
      [0, 0, 0, 4, 0, 3, 2, 1, 0, 0],
      [0, 0, 4, 0, 0, 0, 3, 2, 1, 0],
      [0, 4, 0, 0, 0, 0, 0, 3, 2, 1]
    ]
  end

  #
  # Problem from http://www.cs.cornell.edu/gomes/QUASIdemo.html
  # (n = 10]
  # Pattern #5
  # Note: There are no solutions to this problem.
  #
  def puzzle(9) do
    [
      [0, 0, 0, 0, 0, 0, 0, 0, 0, 1],
      [0, 0, 0, 0, 0, 0, 0, 0, 1, 0],
      [0, 0, 0, 0, 0, 0, 0, 1, 0, 0],
      [0, 0, 0, 0, 0, 0, 2, 0, 0, 0],
      [0, 0, 0, 0, 0, 1, 0, 0, 0, 0],
      [0, 0, 0, 0, 1, 0, 0, 0, 0, 0],
      [0, 0, 0, 1, 0, 0, 0, 0, 0, 0],
      [0, 0, 1, 0, 0, 0, 0, 0, 0, 0],
      [0, 1, 0, 0, 0, 0, 0, 0, 0, 0],
      [1, 0, 0, 0, 0, 0, 0, 0, 0, 0]
    ]
  end

  #
  #
  #
  def run(opts \\ []) do
    # Problem 5..7 yields a huge number of solutions.
    # Let's just pick the first.
    1..7
    |> Enum.map(fn p ->
      IO.puts("Running problem #{p}")

      cond do
        p in [5..7] -> solve_puzzle(p, Keyword.put(opts, :num_solutions, 1))
        true -> solve_puzzle(p, opts)
      end
    end)
  end

  def solve_puzzle(id, opts \\ []) do
    quasigroup_completion(puzzle(id), opts)
  end

  #
  # Running problems 8 and 9 (no solution)
  # Takes long time in current Fixpoint version
  ##
  ## Boris Okner: if using AllDifferent.DC.Fast for `latin_square`,
  ## these puzzles will instantly fail due to early propagation.
  def run_unsatisfiable(opts \\ []) do
    Enum.each([8, 9], fn puzzle_id ->
      try do
        solve_puzzle(puzzle_id, opts)
      catch
        {:fail, _} ->
          IO.puts("Puzzle #{puzzle_id} doesn't have solutions")
      end
    end)
  end

  @doc """
  quasigroup_completion(mat,num_sols \\ :infinity)

  Solves the Quasigroup completion problem for the matrix `mat`.
  `num_sols` are the required number of solutions, defaults to :infinity.

  """
  def quasigroup_completion(mat, opts \\ []) do
    n = length(mat)
    dom = 1..n

    #
    # Decision variables
    #

    x =
      for i <- 0..(n - 1) do
        for j <- 0..(n - 1) do
          v = mat_at(mat, i, j)

          if v > 0 do
            # > 0: this is a hint
            IntVariable.new(v, name: "x[#{i},#{j}]")
          else
            # 0: unknown
            IntVariable.new(dom, name: "x[#{i},#{j}]")
          end
        end
      end

    x_flatten = List.flatten(x)

    #
    # Constraints
    #
    constraints = latin_square(x)

    model =
      Model.new(
        x_flatten,
        constraints
      )

    Logger.configure(level: :info)

    opts =
      Keyword.merge(default_opts(), opts)
      |> then(fn opts ->
        Keyword.put(opts, :stop_on, {:max_solutions, opts[:num_solutions]})
      end)

    {:ok, result} =
      CPSolver.solve(
        model,
        opts
      )

    ## Print last solution
    print_matrix(result.solutions |> List.last(), n, n, "~3w")
    ##
    IO.inspect(result.statistics)

    {:ok, result}
  end

  defp default_opts() do
    [
      search: {:first_fail, :indomain_max},
      # search: {:first_fail, :indomain_min},
      # search: {:first_fail, :indomain_random},
      # search: {:input_order, :indomain_max},
      num_solutions: :infinity,
      timeout: :timer.minutes(5)
    ]
  end
end
