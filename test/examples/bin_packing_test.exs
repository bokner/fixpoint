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

  # test "binpacking p03" do
  #   test_bin_packing("p03")
  # end

  test "binpacking p03_1" do
    test_bin_packing("p03_1")
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

    expected_solution =
      File.read!("data/bin_packing/#{dataset}/#{dataset}_s.txt")
      |> String.split("\n", trim: true)
      |> Enum.map(&String.to_integer/1)
      |> Enum.with_index()
      |> Enum.reduce(%{}, fn {bin_1_based, item_0_based}, acc ->
        bin_0_based = bin_1_based - 1
        Map.update(acc, bin_0_based, [item_0_based], fn items -> [item_0_based | items] end)
      end)

    model = BinPacking.model(weights, max_capacity, :minimize)
    # {:ok, result} = CPSolver.solve(model)
    {:ok, result} = CPSolver.solve(model, search: {:first_fail, :indomain_max})
    assert_solutions(expected_solution, result)
  end

  defp assert_solutions(expected, solution) do
    assert BinPacking.check_solution(expected, solution)
  end
end
