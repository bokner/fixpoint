defmodule CPSolver.Examples.Sudoku do
  alias CPSolver.Constraint.AllDifferent
  alias CPSolver.IntVariable

  require Logger
  @queen_symbol "\u2655"

  ## Sudoku puzzle is a list of n rows, each one has n elements.
  ## If puzzle[i, j] = 0, the cell (i,j) is not filled.
  ##
  ## 4x4 example:
  ##
  ## puzzle4x4 = [[1, 0, 0, 0], [2, 3, 1, 0], [0, 0, 0, 2], [0, 2, 0, 0]]
  ##
  ## We use AllDifferent constraint here.
  ##
  def solve(puzzle, solver_opts \\ []) do
    dimension = length(puzzle)
    ## Check if puzzle is valid
    sq_root = :math.sqrt(dimension)
    square = floor(sq_root)

    if cols = length(hd(puzzle)) != dimension || sq_root != square do
      throw({:puzzle_not_valid, %{rows: dimension, cols: cols, square: square}})
    end

    domain = 1..dimension
    subsquare_range = 0..(square - 1)

    ## Variables
    cells =
      Enum.map(0..(dimension - 1), fn i ->
        Enum.map(0..(dimension - 1), fn j ->
          var_name = "cell(#{i}, #{j})"
          cell = Enum.at(puzzle, i) |> Enum.at(j)

          if cell in domain do
            ## Cell is filled
            IntVariable.new(cell, name: var_name)
          else
            IntVariable.new(domain, name: var_name)
          end
        end)
      end)

    # Each row has different numbers
    row_constraints =
      Enum.map(cells, fn row -> {AllDifferent, row} end)

    # Each column has different numbers
    column_constraints =
      Enum.zip_with(cells, &Function.identity/1)
      |> Enum.map(fn column -> {AllDifferent, column} end)

    subsquare_constraints =
      group_by_subsquares(cells) |> Enum.map(fn square_vars -> {AllDifferent, square_vars} end)

    #    for i <- 0..square-1, j <- 0..square-1 do
    #     for k <- i*square..(i*square + square - 1), l <- j*square..(j*square + square - 1) do
    #       {k, l}
    #     end
    #     |> List.flatten()
    #     |> tap(fn square_cells -> Logger.error(inspect(square_cells)); Logger.error("____") end)
    #     |> for m <- 0..dimension - 2, n <- m+1..dimension - 1 do
    #       {NotEqual, 1}
    #     end
    #   end
    # ## No same number in sub-squares

    # |> List.flatten()
    # |> Enum.uniq()

    model = %{
      variables: cells |> List.flatten(),
      constraints: row_constraints ++ column_constraints ++ subsquare_constraints
    }

    {:ok, _solver} =
      CPSolver.solve(model, solver_opts)
  end

  defp group_by_subsquares(cells) do
    square = :math.sqrt(length(cells)) |> floor

    for i <- 0..(square - 1), j <- 0..(square - 1) do
      for k <- (i * square)..(i * square + square - 1),
          l <- (j * square)..(j * square + square - 1) do
        Enum.at(cells, k) |> Enum.at(l)
      end
    end
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
