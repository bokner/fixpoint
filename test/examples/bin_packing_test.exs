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

  defp test_bin_packing(dataset, upper_bound \\ nil) do
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

    upper_bound =
      if upper_bound == :find_upper_bound do
        UpperBound.first_fit_decreasing(weights, max_capacity)
      else
        upper_bound
      end

    model = BinPacking.model(weights, max_capacity, upper_bound)
    {:ok, result} = CPSolver.solve(model, search: {:first_fail, :indomain_max}, timeout: :timer.seconds(5))

    assert BinPacking.check_solution(result, weights, max_capacity)
  end
end
