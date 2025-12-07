defmodule CPSolverTest.Examples.BinPacking do
  use ExUnit.Case

  alias CPSolverTest.Examples.BinPacking
  alias CPSolver.Examples.BinPacking

  test "small binpacking" do
    item_weights = [4, 7, 2, 6, 3]

    model = BinPacking.model(item_weights)

    {:ok, results} = CPSolver.solve(model)

    BinPacking.print_result(results)

    assignments =
      results.variables
      |> Enum.filter(&is_integer(&1))
      |> Enum.with_index()
      |> Enum.map(fn {value, idx} -> {"item_#{idx + 1}", value} end)

    IO.puts("Item - Bin assigments:")
    Enum.each(assignments, fn {item, bin} -> IO.puts("#{item} in bin #{bin}") end)
  end
end
