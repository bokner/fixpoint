defmodule CPSolver.Examples.BinPacking do
  @moduledoc """
  Bin Packing Problem Example

  Given:
  - n: items, each with weights w[i]
  - b: max. bin capacity 

  The goal is to assign each item to a bin such that:
  sum of item weights in each bin <= capacity and the
  number of bins used is minimized.
  """

  alias CPSolver.IntVariable, as: Variable
  alias CPSolver.Model
  alias CPSolver.Constraint.Sum
  alias CPSolver.Constraint.LessOrEqual
  import CPSolver.Variable.View.Factory
  alias CPSolver.Objective

  def minimization_model(item_weights, max_bin_capacity) do
    num_items = length(item_weights)
    num_bins = num_items
 
    # x[i][j] item i assigned to bin j
    indicators =
      for i <- 0..(num_items - 1) do
        for j <- 0..(num_bins - 1) do
          Variable.new(0..1, name: "item_#{i}_in_bin_#{j}")
        end
      end

    # bin j is used
    bin_used =
      for j <- 0..(num_bins - 1) do
        Variable.new(0..1, name: "bin_#{j}_used")
      end

    # total weight in bin j
    bin_load =
      for j <- 0..(num_bins - 1) do
        Variable.new(0..max_bin_capacity, name: "bin_load_#{j}")
      end

    one = Variable.new(1..1, name: "one")

    item_assignment_constraints =
      Enum.map(indicators, fn inds ->
        Sum.new(one, inds)
      end)

    bin_load_constraints =
      Enum.with_index(bin_load)
      |> Enum.map(fn {load_var, j} ->
        views =
          Enum.with_index(indicators)
          |> Enum.map(fn {inds_for_item, i} ->
            mul(Enum.at(inds_for_item, j), Enum.at(item_weights, i))
          end)

        Sum.new(load_var, views)
      end)

    capacity_constraints =
      Enum.zip(bin_load, bin_used)
      |> Enum.map(fn {load, used} ->
        LessOrEqual.new(load, mul(used, max_bin_capacity))
      end)

    total_bins_used =
      Variable.new(0..num_bins, name: "total_bins_used")

    total_bins_constraint =
      Sum.new(total_bins_used, bin_used)

    symmetry_breaking =
      Enum.zip(bin_used, tl(bin_used))
      |> Enum.map(fn {a, b} ->
        LessOrEqual.new(b, a)
      end)

    constraints =
      item_assignment_constraints ++
        bin_load_constraints ++
        capacity_constraints ++
        symmetry_breaking ++
        [total_bins_constraint]

    vars =
      bin_used ++
        [total_bins_used] ++
        bin_load ++
        List.flatten(indicators)

    Model.new(
      vars,
      constraints,
      objective: Objective.minimize(total_bins_used)
    )
  end

  def print_result(result) do
    solution = List.first(result.solutions)

    if solution == nil do
      IO.puts("No solution found.")
    else
      Enum.each(items_by_bin(result), fn {bin, items} ->
        IO.puts("Bin #{bin} contains: #{Enum.join(items, ", ")}")
      end)
    end
  end

  defp items_by_bin(result) do
    solution = List.first(result.solutions)
    variable_names = result.variables

    assignments =
      Enum.zip(variable_names, solution)
      |> Enum.filter(fn {name, value} ->
        is_binary(name) and value == 1 and String.starts_with?(name, "item_")
      end)

    Enum.reduce(assignments, %{}, fn {name, _}, acc ->
      case String.split(name, "_in_bin_") do
        [item, bin] ->
          Map.update(acc, bin, [item], fn items -> [item | items] end)

        _ ->
          acc
      end
    end)
    |> Enum.map(fn {bin_str, items} ->
      bin = String.to_integer(bin_str)

      item_ids =
        items
        |> Enum.map(fn item ->
          item
          |> String.replace_prefix("item_", "")
          |> String.to_integer()
        end)

      {bin, item_ids}
    end)
    |> Map.new()
  end

  defp canonical_bins(solution) do
    solution
    |> Map.values()
    |> Enum.map(&Enum.sort/1)
    |> Enum.sort()
  end

  def check_solution(expected, solution) do
    expected |> canonical_bins() |> length() ==
      solution |> items_by_bin() |> canonical_bins() |> length()
  end

  def model(item_weights, max_bin_capacity, type \\ :minimize)

  def model(item_weights, max_bin_capacity, :minimize),
    do: minimization_model(item_weights, max_bin_capacity)
end
