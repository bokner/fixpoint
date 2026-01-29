defmodule CPSolverTest.Examples.BinPacking do
  use ExUnit.Case

  alias CPSolver.Examples.BinPacking
  alias CPSolver.Examples.BinPacking.UpperBound

  test "binpacking p01" do
    test_bin_packing("p01")
  end

  test "binpacking p02" do
    test_bin_packing("p02", :find_upper_bound)
  end

  test "binpacking p03" do
    test_bin_packing("p03")
  end

  test "binpacking p04" do
    test_bin_packing("p04", :find_upper_bound)
  end

  test "first_fit_decreasing" do
    weights = [2, 5, 4, 7, 1, 3, 8]
    capacity = 10
    assert 3 = UpperBound.first_fit_decreasing(weights, capacity)
  end

  defp test_bin_packing(dataset, upper_bound \\ nil) do
    weights =
      File.read!("data/bin_packing/#{dataset}/#{dataset}_w.txt")
      |> String.split("\n", trim: true)
      |> Enum.map(fn line ->
        line
        |> String.trim()
        |> String.to_integer()
      end)

    capacity =
      File.read!("data/bin_packing/#{dataset}/#{dataset}_c.txt")
      |> String.trim()
      |> String.to_integer()

    upper_bound =
      if upper_bound == :find_upper_bound do
        UpperBound.first_fit_decreasing(weights, capacity)
      else
        upper_bound
      end

    model = BinPacking.model(weights, capacity, upper_bound)
    {:ok, result} = CPSolver.solve(model, search: {:first_fail, :indomain_max}, timeout: :timer.seconds(5))

    assert BinPacking.check_solution(result, weights, capacity)
  end
end
