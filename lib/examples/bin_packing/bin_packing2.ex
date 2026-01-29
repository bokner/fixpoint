  defmodule CPSolver.Examples.BinPacking2 do

  alias CPSolver.IntVariable, as: Variable
  alias CPSolver.Model
  alias CPSolver.Constraint.Sum
  alias CPSolver.Constraint.{Equal, LessOrEqual, Less, Reified}
  import CPSolver.Variable.View.Factory
  alias CPSolver.Objective

  def model(%{weights: weights, max_capacity: capacity} = _instance, upper_bound \\ nil) do
    model(weights, capacity, upper_bound)
  end

  def model(weights, capacity, upper_bound) do
    num_items = length(weights)
    num_bins = upper_bound || num_items
    ## Objective
    lb = ceil(Enum.sum(weights) / capacity)

    total_bins_used =
      Variable.new(
      lb..num_bins,
        name: "total_bins_used"
      )

    ## Assignments (x[i] = b <=> x[i] in bin b)
    x = Enum.map(1..num_items, fn idx -> Variable.new(1..num_bins, name: "x_#{idx}") end)
    ## Bin loads
    l = Enum.map(1..num_bins, fn idx -> Variable.new(0..capacity, name: "bin_#{idx}_load") end)
    bin_used = List.duplicate(Variable.new(1), lb) ++
      Enum.map(lb+1..num_bins, fn idx -> Variable.new(0..1, name: "bin_#{idx}_used") end)


    ## placement indicators
    ## inBin[j][i] = 1 if item i is placed in bin j

    indicators = for i <- 1..num_bins do
      for j <- 1..num_items do
        Variable.new(0..1, name: "in_bin[#{i}][#{j}]")
      end
    end

    ub_constraint = LessOrEqual.new(total_bins_used, num_bins)

    assignment_constraints =
    for i <- 1..num_bins do
      bin_indicators = Enum.at(indicators, i - 1)
      for j <- 1..num_items do
        ind_ij = Enum.at(bin_indicators, j - 1)
        x_j = Enum.at(x, j - 1)
        Reified.new(Equal.new(x_j, i), ind_ij)
      end
    end

    # load constraints
    bin_content_constraints =
    for i <- 1..num_bins do
      bin_load = Enum.at(l, i - 1)
      bin_item_indicators = Enum.at(indicators, i - 1)
      bin_item_weights = for j <- 1..num_items do
        mul(Enum.at(bin_item_indicators, j - 1), Enum.at(weights, j - 1))
      end
      [
        ## Load is a sum of item weights
        Sum.new(bin_load, bin_item_weights),
        ## The bin is used if there is a load in there
        Reified.new(Less.new(0, bin_load), Enum.at(bin_used, i - 1))
      ]
    end

    ## Total bins used
    total_bins_constraint = Sum.new(total_bins_used, bin_used)

    # redundant constraint : sum of bin load = sum of item weights

    bin_load_sum_constraint = Sum.new(Enum.sum(weights), l)

  constraints =
      [
        ub_constraint,
        total_bins_constraint,
        assignment_constraints,
        bin_content_constraints,
        symmetry_breaking_constraints(bin_used, l, num_bins),
        bin_load_sum_constraint
      ]

    vars =
      [bin_used, l, x] |> List.flatten()

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

    used_bins_first_constraints =
      Enum.map(1..(num_bins - 2), fn bin_idx ->
        bin = Enum.at(bin_used, bin_idx)
        next_bin = Enum.at(bin_used, bin_idx + 1)
        LessOrEqual.new(next_bin, bin)
      end)

    # 2. Arrange bin loads in decreasing order
    decreasing_loads_constraints =
      for i <- 0..num_bins-2 do
        LessOrEqual.new(Enum.at(bin_load, i + 1), Enum.at(bin_load, i))
    end

    [
      decreasing_loads_constraints,
      used_bins_first_constraints
    ]
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

    true = all_item_indices == MapSet.new(1..(length(item_weights)))
    ## For each bin, the load is the sum of weights of items placed to bin
    true =
      Enum.all?(Enum.zip(bin_loads, bin_contents), fn {load, items} ->
        load == Enum.sum_by(items, fn item_idx -> Enum.at(item_weights, item_idx - 1) end)
      end)

    ## The total sum of bin weights equals the total sum of item weights
    true = Enum.sum(item_weights) == Enum.sum(bin_loads)
  end

  def solution_to_bin_content(solution, weights, _capacity, objective) do
    solution
    ## Skip bin indicators
    |> Enum.drop_while(fn v -> v in [0, 1] end)
    |> Enum.split(objective)
    |> then(fn {loads, rest} ->
      bin_contents =
      ## Take item assignments
      rest
      |> Enum.drop_while(fn v -> v == 0 end)
      |> Enum.take(length(weights))
      ## ... make inverse (bin -> items map)
      |> Enum.with_index(1)
      |> Enum.group_by(fn {bin, _idx} -> bin end, fn {_bin, idx} -> idx end)
      |> Enum.map(fn {_idx, items} -> MapSet.new(items) end)

      %{loads: loads, bin_contents: bin_contents}
    end)
  end

end
