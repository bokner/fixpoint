defmodule CPSolverTest.Examples.BinPacking do
  use ExUnit.Case

  alias CPSolverTest.Examples.BinPacking
  alias CPSolver.Examples.BinPacking

  test "binpacking p01" do
    test_bin_packing("p01")
  end

  test "binpacking p02" do
    test_bin_packing("p02")
  end

  test "binpacking p03" do
    test_bin_packing("p03")
  end

  test "binpacking p04" do
    test_bin_packing("p04")
  end

  defp test_bin_packing(dataset) do
    weights =
      File.read!("data/bin_packing/#{dataset}/#{dataset}_w.txt")
      |> String.split("\n", trim: true)
      |> Enum.map(fn line ->
        line
        |> String.trim()
        |> String.to_integer()
      end)

    max_capacity =
      File.read!("data/bin_packing/#{dataset}/#{dataset}_c.txt")
      |> String.trim()
      |> String.to_integer()

    model = BinPacking.model(weights, max_capacity, :minimize)
    {:ok, result} = CPSolver.solve(model, search: {:first_fail, :indomain_max})

    assert BinPacking.check_solution(result, weights, max_capacity)
  end
end
