defmodule CPSolverTest.Examples.BinPacking do
  use ExUnit.Case

  alias CPSolver.Examples.BinPacking2, as: BinPacking
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

  test "binpacking p05" do
    test_bin_packing("p05", :find_upper_bound)
  end

  defp test_bin_packing(dataset, upper_bound \\ nil) do
    IO.puts("Test #{dataset}")

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

    solution_handler = fn solution ->
      IO.puts("#{inspect(Enum.map(solution, fn {_name, solution} -> solution end))}")
    end

    {:ok, result} =
      CPSolver.solve(model,
        search: BinPacking.search(model),
        space_threads: 8,
        solution_handler: solution_handler,
        timeout: :timer.seconds(30)
      )

    # IO.inspect(result.statistics)
    assert BinPacking.check_solution(result, weights, max_capacity)
  end
end
