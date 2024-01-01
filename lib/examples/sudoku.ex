defmodule CPSolver.Examples.Sudoku do
  alias CPSolver.Constraint.AllDifferent.FWC, as: AllDifferent
  alias CPSolver.IntVariable
  alias CPSolver.Model

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

  def puzzles() do
    %{
      hard9x9:
        "..6....9....5.17..2..9..3...7..3..5..2..9..6..4..8..2...1..3..4..52.7....3....8..",
      hard9x9_2:
        "4...39.2..56............6.4......9..5..1..2...9..27.3..37............8.69.8.1....",
      s9x9_1: "85...24..72......9..4.........1.7..23.5...9...4...........8..7..17..........36.4.",
      s9x9_5: "8..6..9.5.............2.31...7318.6.24.....73...........279.1..5...8..36..3......",
      s4x4: [[1, 0, 0, 0], [2, 3, 1, 0], [0, 0, 0, 2], [0, 2, 0, 0]],
      s9x9_clue17_easy:
        "52...6.........7.13...........4..8..6......5...........418.........3..2...87.....",
      s9x9_clue17_hard:
        "......8.16..2........7.5......6...2..1....3...8.......2......7..4..8....5...3....",
      s9x9_clue17_rosetta_difficult:
        "..............3.85..1.2.......5.7.....4...1...9.......5......73..2.1........4...9"
    }
    |> Map.new(fn {name, puzzle} -> {name, normalize(puzzle)} end)
  end

  def solve(puzzle, solver_opts \\ []) do
    puzzle
    |> model()
    |> CPSolver.solve(solver_opts)
  end

  defp normalize(puzzle) when is_binary(puzzle) do
    sudoku_string_to_grid(puzzle)
  end

  defp normalize(puzzle) when is_list(puzzle) do
    puzzle
  end

  def model(puzzle) when is_list(puzzle) do
    dimension = length(puzzle)
    ## Check if puzzle is valid
    sq_root = :math.sqrt(dimension)
    square = floor(sq_root)

    if cols = length(hd(puzzle)) != dimension || sq_root != square do
      throw({:puzzle_not_valid, %{rows: dimension, cols: cols, square: square}})
    end

    numbers = 1..dimension

    ## Variables
    cells =
      Enum.map(0..(dimension - 1), fn i ->
        Enum.map(0..(dimension - 1), fn j ->
          cell = Enum.at(puzzle, i) |> Enum.at(j)

          cell_name = [i + 1, j + 1]

          if cell in numbers do
            ## Cell is filled
            IntVariable.new(cell, name: cell_name)
          else
            IntVariable.new(numbers, name: cell_name)
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

    Model.new(
      cells |> List.flatten(),
      row_constraints ++ column_constraints ++ subsquare_constraints
    )
  end

  def model(puzzle) when is_binary(puzzle) do
    puzzle
    |> normalize()
    |> model()
  end

  def solve_and_print(puzzle, opts \\ []) do
    Logger.configure(level: :info)

    opts = Keyword.merge(default_opts(), opts)
    IO.puts("Sudoku:")
    IO.puts(print_grid(puzzle))

    {:ok, result} =
      CPSolver.solve_sync(
        model(puzzle),
        opts
      )

    case result.solutions do
      [] ->
        "No solutions found within #{opts[:timeout]} milliseconds"

      [s | _rest] ->
        print_grid(s)
        |> tap(fn _ -> check_solution(s) && Logger.notice("Solution checked!") end)
    end

    {:ok, result}
  end

  def check_solution(solution) do
    ## We assume it's 1-dimensional list
    dim = :math.sqrt(length(solution)) |> floor()
    grid = Enum.chunk_every(solution, dim)
    transposed = Enum.zip_with(grid, &Function.identity/1)
    squares = group_by_subsquares(grid)

    checker_fun = fn line -> Enum.sort(line) == Enum.to_list(1..dim) end

    Enum.all?([grid, transposed, squares], fn arrangement ->
      Enum.all?(arrangement, checker_fun)
    end)
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

  def print_grid(cells) when is_binary(cells) do
    cells
    |> sudoku_string_to_grid()
    |> print_grid()
  end

  def print_grid(cells) when is_list(cells) do
    {dim, grid} =
      if is_list(hd(cells)) do
        {length(cells), cells}
      else
        dim = :math.sqrt(length(cells)) |> floor
        {dim, Enum.chunk_every(cells, dim)}
      end

    square_dim = :math.sqrt(dim) |> floor()

    gridline =
      "+" <>
        String.duplicate(String.duplicate("-", 2 * square_dim + 1) <> "+", square_dim) <> "\n"

    gridcol = "| "

    ([
       "\n"
       | for i <- 0..(dim - 1) do
           [if(rem(i, square_dim) == 0, do: gridline, else: "")] ++
             for j <- 0..(dim - 1) do
               "#{if rem(j, square_dim) == 0, do: gridcol, else: ""}" <>
                 "#{print_cell(Enum.at(Enum.at(grid, i), j))} "
             end ++ ["#{gridcol}\n"]
         end
     ] ++ [gridline])
    |> IO.puts()
  end

  defp print_cell(0) do
    "."
  end

  defp print_cell(cell) do
    to_string(cell)
  end

  defp default_opts() do
    [timeout: 2_500, stop_on: {:max_solutions, 1}]
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
