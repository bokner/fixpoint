defmodule CPSolver.Examples.Sudoku do
  alias CPSolver.Constraint.AllDifferent
  alias CPSolver.IntVariable

  require Logger

  ## Sudoku puzzle is a list of n rows, each one has n elements.
  ## If puzzle[i, j] = 0, the cell (i,j) is not filled.
  ##
  ## 4x4 example:
  ##
  ## puzzle4x4 = [[1, 0, 0, 0], [2, 3, 1, 0], [0, 0, 0, 2], [0, 2, 0, 0]]
  ##
  ## 9x9 examples:
  ## "4...39.2..56............6.4......9..5..1..2...9..27.3..37............8.69.8.1...." - 1 solution (hard!)
  ## "85...24..72......9..4.........1.7..23.5...9...4...........8..7..17..........36.4." - 1 solution
  ## "8..6..9.5.............2.31...7318.6.24.....73...........279.1..5...8..36..3......" - 5 solutions
  ##
  # +-------+-------+-------+
  # | 4 . . | . 3 9 | . 2 . |
  # | . 5 6 | . . . | . . . |
  # | . . . | . . . | 6 . 4 |
  # +-------+-------+-------+
  # | . . . | . . . | 9 . . |
  # | 5 . . | 1 . . | 2 . . |
  # | . 9 . | . 2 7 | . 3 . |
  # +-------+-------+-------+
  # | . 3 7 | . . . | . . . |
  # | . . . | . . . | 8 . 6 |
  # | 9 . 8 | . 1 . | . . . |
  # +-------+-------+-------+

  ## puzzle9x9 =
  #
  ## We use AllDifferent constraint here.
  ##

  def solve(puzzle, solver_opts \\ [])

  def solve(puzzle, solver_opts) when is_binary(puzzle) do
    sudoku_string_to_grid(puzzle)
    |> solve(solver_opts)
  end

  def solve(puzzle, solver_opts) when is_list(puzzle) do
    dimension = length(puzzle)
    ## Check if puzzle is valid
    sq_root = :math.sqrt(dimension)
    square = floor(sq_root)

    if cols = length(hd(puzzle)) != dimension || sq_root != square do
      throw({:puzzle_not_valid, %{rows: dimension, cols: cols, square: square}})
    end

    domain = 1..dimension

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

  def print_grid(cells) do
      gridline = "+-------+-------+-------+\n"
      gridcol = "| "

      [
        "\n" |
        for i <- 0..8 do
          [(if rem(i, 3) == 0, do: gridline, else: "")] ++
          (for j <- 0..8 do
             "#{if rem(j, 3) == 0, do: gridcol, else: ""}" <>
             "#{print_cell(Enum.at(Enum.at(cells, i), j))} "
           end) ++ ["#{gridcol}\n"]
        end
      ] ++ [gridline]
  end

  defp print_cell(0) do
    "."
  end

  defp print_cell(cell) do
    to_string(cell)
  end

  def sudoku_string_to_grid(sudoku_str) do
    dim = :math.sqrt(String.length(sudoku_str)) |> floor()
    str0 = String.replace(sudoku_str, ".", "0")

    for i <- 0..(dim - 1) do
      for j <- 0..(dim - 1) do
        String.to_integer(String.at(str0, i * dim + j))
      end
    end
  end
end
