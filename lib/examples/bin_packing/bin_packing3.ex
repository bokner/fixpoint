defmodule CPSolver.Examples.BinPacking3 do
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
  alias CPSolver.Constraint.{Equal, Less, LessOrEqual, Reified, HalfReified, Maximum}
  import CPSolver.Variable.View.Factory
  alias CPSolver.Objective

  def minimization_model(item_weights, max_bin_capacity, upper_bound \\ nil) do
    num_items = length(item_weights)
    num_bins = upper_bound || num_items
    lower_bound = ceil(Enum.sum(item_weights) / max_bin_capacity)

    # x[i][j] item i assigned to bin j
    indicators =
      for i <- 0..(num_items - 1) do
        for j <- 0..(num_bins - 1) do
          Variable.new(0..1, name: "item_#{i}_in_bin_#{j}")
        end
      end

    x = for i <- 1..num_items do
      Variable.new(1..num_bins, name: "x_#{i}")
    end

    total_bins_used =
      Variable.new(lower_bound..num_bins,
        name: "total_bins_used"
      )

    # indicators for bin: bin[j] is used iff bin_used[j] = 1
    bin_used =
      for j <- 1..(num_bins) do
        ## First `lower_bound` bins are to be used
        d = (j <= lower_bound) && 1 || 0..1
        Variable.new(d, name: "bin_#{j}_used")
      end

    # total weight in bin j
    bin_load =
      for j <- 0..(num_bins - 1) do
        Variable.new(0..max_bin_capacity, name: "bin_load_#{j}")
      end

    ###################
    ### Constraints ###
    ###################
    upper_bound_constraint = LessOrEqual.new(total_bins_used, num_bins)

    item_assignment_constraints =
      Enum.map(indicators, fn inds ->
        [
          Sum.new(1, inds)
        ]
      end) ++
      for i <- 1..num_items do
        x_i = Enum.at(x, i - 1)
        indicators_i = Enum.at(indicators, i - 1)
        for j <- 1..num_bins do
          HalfReified.new(Equal.new(x_i, j), Enum.at(indicators_i, j - 1))
        end
      end


    bin_load_constraints =
      Enum.with_index(bin_load)
      |> Enum.map(fn {load_var, j} ->
        views =
          Enum.with_index(indicators)
          |> Enum.map(fn {inds_for_item, i} ->
            mul(Enum.at(inds_for_item, j), Enum.at(item_weights, i))
          end)
          total_load = Sum.new(load_var, views)
          if j <= lower_bound do
            total_load
          else
            [
              HalfReified.new(Less.new(0, load_var), Enum.at(bin_used, j - 1)), total_load
            ]
        end
      end)

    capacity_constraints =
      Enum.zip(bin_load, bin_used)
      |> Enum.map(fn {load, used} ->
        LessOrEqual.new(load, mul(used, max_bin_capacity))
      end)

    total_bins_constraint =
      Sum.new(total_bins_used, bin_used)

    max_bin_constraint = Maximum.new(total_bins_used, x)

    bin_load_sum_constraint = Sum.new(Enum.sum(item_weights), bin_load)
    #####################################
    ### end of constraint definitions ###
    #####################################

    constraints =
      [
        upper_bound_constraint,
        item_assignment_constraints,
        bin_load_constraints,
        capacity_constraints,
        symmetry_breaking_constraints(bin_used, bin_load, num_bins),
        #total_bins_constraint,
        max_bin_constraint,
        bin_load_sum_constraint
      ]

    vars =
      [bin_load, bin_used] |> List.flatten()

    Model.new(
      vars,
      constraints,
      objective: Objective.minimize(total_bins_used)
    )
  end

  defp symmetry_breaking_constraints(bin_used, bin_load, num_bins) do
    # Symmetry breaking
    # 1. Only allow bin j to be used if all bins < j are used.
    # This prevents the solver from seeing equivalent packings as different solutions.
    used_bins_first =
      Enum.map(1..(num_bins - 2), fn bin_idx ->
        bin = Enum.at(bin_used, bin_idx)
        next_bin = Enum.at(bin_used, bin_idx + 1)
        LessOrEqual.new(next_bin, bin)
      end)
    # 2. Arrange bin loads in decreasing order
    decreasing_loads =
      for i <- 0..num_bins - 2 do
        LessOrEqual.new(Enum.at(bin_load, i + 1), Enum.at(bin_load, i))
      end

    [
      used_bins_first,
      decreasing_loads
    ]
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
      solution_to_bin_content(best_solution, item_weights, max_capacity, result.objective)

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

  def solution_to_bin_content(solution, item_weights, _max_capacity, objective) do
    num_items = length(item_weights)
    ## First block in the solution is 'bin indicators',
    ## followed by the objective value
    ## The number of indicators is given to the solver as 'upper bound',
    ## and is used in the model as initial number of bins.
    {bin_indicators, rest} = Enum.split_while(solution, fn el -> el != objective end)
    total_bins = length(bin_indicators)
    {all_bin_loads, rest} = Enum.split(tl(rest), total_bins)
    {assignments, _rest} = Enum.split(rest, num_items * total_bins)

    ## placements[i] row corresponds to the placement of the item
    ## (position of 1 signifies the bin the item was assigned to)

    placements = Enum.chunk_every(assignments, total_bins)

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

    %{loads: Enum.take(all_bin_loads, objective), bin_contents: bin_contents}
  end

  def model(item_weights, max_bin_capacity, upper_bound, type \\ :minimize)

  def model(item_weights, max_bin_capacity, upper_bound, :minimize),
    do: minimization_model(item_weights, max_bin_capacity, upper_bound)
end
