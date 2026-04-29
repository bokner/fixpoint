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

  test "Gecode example" do
    capacity = 100
    weights = [99,98,95,95,95,94,94,91,88,87,86,85,76,74,73,71,68,60,55,54,51,
    45,42,40,39,39,36,34,33,32,32,31,31,30,29,26,26,23,21,21,21,19,
    18,18,16,15,5,5,4,1]
    test_bin_packing(weights, capacity, :find_upper_bound)
  end

  test "first_fit_decreasing" do
    weights = [2, 5, 4, 7, 1, 3, 8]
    capacity = 10
    assert 3 = UpperBound.first_fit_decreasing(weights, capacity)
  end

  defp test_bin_packing(dataset, upper_bound \\ nil) when is_binary(dataset) do
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

      solve_and_assert(weights, capacity, upper_bound)
    end

    defp test_bin_packing(weights, capacity, upper_bound) do
      solve_and_assert(weights, capacity, upper_bound)
    end

    defp solve_and_assert(weights, capacity, upper_bound) do
      upper_bound =
        if upper_bound == :find_upper_bound do
          UpperBound.first_fit_decreasing(weights, capacity)
        else
          upper_bound
        end

      {:ok, result} =
        BinPacking.solve(weights, capacity,
          upper_bound: upper_bound,
          timeout: 500
        )

      assert BinPacking.check_solution(result, weights, capacity)
    end
end
