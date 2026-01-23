defmodule CPSolver.Examples.BinPacking do
  @moduledoc """
  Bin Packing Problem Example

  Given:
  - n: items, each with weights w[i]
  - b: max. bin capacity

  The goal is to assign each item to a bin such that:
  Sum of item weights in each bin <= capacity and the
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
      [ Variable.new(1, name: "bin_0_used") |
      for j <- 1..(num_bins - 1) do
        Variable.new(0..1, name: "bin_#{j}_used")
      end
    ]

    # total weight in bin j
    bin_load =
      for j <- 0..(num_bins - 1) do
        Variable.new(0..max_bin_capacity, name: "bin_load_#{j}")
      end

    item_assignment_constraints =
      Enum.map(indicators, fn inds ->
        Sum.new(1, inds)
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
      Variable.new(ceil(Enum.sum(item_weights) / max_bin_capacity)..num_bins,
        name: "total_bins_used"
      )

    total_bins_constraint =
      Sum.new(total_bins_used, bin_used)

    # Only allow bin j to be used if all bins < j are used.
    # This prevents the solver from seeing equivalent packings as different solutions.
    symmetry_breaking =
      Enum.map(1..(num_bins - 2), fn bin_idx ->
        bin = Enum.at(bin_used, bin_idx)
        next_bin = Enum.at(bin_used, bin_idx + 1)
        LessOrEqual.new(next_bin, bin)
      end)


    bin_load_sum_constraint = Sum.new(Enum.sum(item_weights), bin_load)

    constraints =
      [
        item_assignment_constraints,
        bin_load_constraints,
        capacity_constraints,
        symmetry_breaking,
        total_bins_constraint,
        bin_load_sum_constraint
      ]

    vars =
      [bin_used, total_bins_used, bin_load, indicators] |> List.flatten()

    Model.new(
      vars,
      constraints,
      objective: Objective.minimize(total_bins_used)
    )
  end

  def print_result(%{status: status} = result) do
    result =
      cond do
        status == :unsatisfiable ->
          "Solution does not exist"

        status == :unknown ->
          "No solution found  within allotted time"

        true ->
          Enum.map_join(items_by_bin(result), "\n", fn {bin, items} ->
            "Bin #{bin} contains: #{Enum.join(items, ", ")}"
          end)
      end

    IO.puts(result)
  end

  defp items_by_bin(result) do
    solution = List.last(result.solutions)
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

  def check_solution(result, item_weights, max_capacity) do
    best_solution = result.solutions |> List.last()

    %{loads: bin_loads, bin_contents: bin_contents} =
      solution_to_bin_content(best_solution, item_weights, max_capacity)

    ## Loads do no exceed max capacity
    true = Enum.all?(bin_loads, fn l -> l <= max_capacity end)
    ## All items are placed into bins
    all_item_indices =
      Enum.reduce(tl(bin_contents), hd(bin_contents), fn bin_items, acc ->
        MapSet.union(acc, bin_items)
      end)

    true = all_item_indices == MapSet.new(0..(length(item_weights) - 1))
    ## For each bin, the load is the sum of weights of items placed to bin
    true =
      Enum.all?(Enum.zip(bin_loads, bin_contents), fn {load, items} ->
        load == Enum.sum_by(items, fn item_idx -> Enum.at(item_weights, item_idx) end)
      end)

    ## The total sum of bin weights equals the total sum of item weights
    true = Enum.sum(item_weights) == Enum.sum(bin_loads)
  end

  def solution_to_bin_content(solution, item_weights, _max_capacity) do
    num_items = length(item_weights)
    {_bins, rest} = Enum.split(solution, num_items)
    total_bins = hd(rest)
    {bin_loads, rest} = Enum.split(tl(rest), total_bins)
    {assignments, _rest} = Enum.split(rest, num_items * num_items)

    ## placements[i] row corresponds to the placement of the item
    ## (position of 1 signifies the bin the item was assigned to)

    placements = Enum.chunk_every(assignments, num_items)

    ### Transpose placements to get bins as rows
    bin_contents =
      Enum.zip_with(placements, &Function.identity/1)
      |> Enum.flat_map(fn bin ->
        bin_content =
          Enum.reduce(Enum.with_index(bin, 0), MapSet.new(), fn {i, pos}, acc ->
            (i == 0 && acc) || MapSet.put(acc, pos)
          end)

        (MapSet.size(bin_content) == 0 && []) || [bin_content]
      end)

    %{loads: bin_loads, bin_contents: bin_contents}
  end

  def model(item_weights, max_bin_capacity, type \\ :minimize)

  def model(item_weights, max_bin_capacity, :minimize),
    do: minimization_model(item_weights, max_bin_capacity)
end
