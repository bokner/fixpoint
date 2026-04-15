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
  alias CPSolver.Constraint.{LessOrEqual, Equal, Reified}
  import CPSolver.Variable.View.Factory

  alias CPSolver.Objective

  alias CPSolver.Examples.BinPacking.{Search, UpperBound}

  require Logger

  def solve(weights, capacity, opts \\ []) do
    upper_bound =
      Keyword.get(opts, :upper_bound, UpperBound.first_fit_decreasing(weights, capacity))

    model = model(weights, capacity, upper_bound)

    opts =
      Keyword.merge(
        [
          search: model.search,
          solution_handler: solution_handler(),
          timeout: :timer.seconds(30),
          upper_bound: upper_bound
        ],
        opts
      )

    Logger.warning("Started")

    Logger.warning("Upper bound: #{opts[:upper_bound]}")

    CPSolver.solve(model, opts)
    |> tap(fn {:ok, res} ->
      if res.status not in [:unknown, :unsatisfiable] do
        (check_solution(res, weights, capacity) && Logger.warning("Solution is valid")) ||
          throw({:error, :invalid_solution})
      else
        Logger.error("No solution found")
      end
    end)
  end

  def minimization_model(item_weights, capacity, upper_bound \\ nil) do
    item_weights = Enum.sort(item_weights, :desc)
    min_weight = List.last(item_weights)
    num_items = length(item_weights)
    num_items_over_half_capacity = Enum.count(item_weights, fn w -> 2 * w > capacity end)
    num_bins = upper_bound || num_items
    lower_bound = max(num_items_over_half_capacity, ceil(Enum.sum(item_weights) / capacity))

    # x[i][j] item i assigned to bin j
    indicators =
      for i <- 1..num_items do
        item_over_half_capacity? = i <= num_items_over_half_capacity

        for j <- 1..num_bins do
          domain =
            if item_over_half_capacity? do
              (i == j && 1) || 0
            else
              0..1
            end

          Variable.new(domain, name: "item_#{i}_in_bin_#{j}")
        end
      end

    total_bins_used =
      Variable.new(lower_bound..num_bins,
        name: "total_bins_used"
      )

    # indicators for bin: bin[i] is used iff bin_used[i] = 1
    bin_used =
      for i <- 1..num_bins do
        ## First `lower_bound` bins are to be used
        ##
        d = (i <= lower_bound && 1) || 0..1
        Variable.new(d, name: "bin_#{i}_used")
      end

    # total weight in bin i
    bin_load =
      for i <- 1..num_bins do
        lb_cap = (i <= lower_bound && min_weight) || 0
        Variable.new(lb_cap..capacity, name: "bin_load_#{i}")
      end

    ###################
    ### Constraints ###
    ###################
    upper_bound_constraint = LessOrEqual.new(total_bins_used, num_bins)

    # item_indicator_constraints =
    #   Enum.map(indicators, fn inds ->
    #     Sum.new(1, inds)
    #   end)

    x = Enum.map(1..num_items, fn idx -> Variable.new(1..num_bins, name: "x_#{idx}") end)

    item_assignment_constraints =
      for i <- 0..(num_items - 1) do
        x_i = Enum.at(x, i)
        bin_indicators = Enum.at(indicators, i)

        for j <- 1..num_bins do
          Reified.new(Equal.new(x_i, j), Enum.at(bin_indicators, j - 1))
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

        Sum.new(load_var, views)
      end)

    capacity_constraints =
      Enum.zip(bin_load, bin_used)
      |> Enum.map(fn {load, used} ->
        LessOrEqual.new(load, mul(used, capacity))
      end)

    total_bins_constraint =
      Sum.new(total_bins_used, bin_used)

    bin_load_sum_constraint = Sum.new(Enum.sum(item_weights), bin_load)
    #####################################
    ### end of constraint definitions ###
    #####################################

    constraints =
      [
        upper_bound_constraint,
        item_assignment_constraints,
        # item_indicator_constraints,
        bin_load_constraints,
        capacity_constraints,
        symmetry_breaking_constraints(bin_used, bin_load, num_bins, num_items_over_half_capacity),
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
    |> Map.put(:search,
      ## if lower_bound = upper_bound, we do not need an advanced strategy
      ## TODO: maybe even run linear BPP (`first_fit_decreasing` etc)
      if lower_bound == num_bins do
        {:first_fail, :indomain_max}
      else
        Search.cdbf(item_weights, x, bin_load, capacity)
      end)
  end

  defp symmetry_breaking_constraints(bin_used, _bin_load, num_bins, _num_over_half_capacity) do
    # Symmetry breaking
    # 1. Only allow bin j to be used if all bins < j are used.
    # This prevents the solver from seeing equivalent packings as different solutions.
    used_bins_first =
      Enum.map(0..(num_bins - 2), fn bin_idx ->
        bin = Enum.at(bin_used, bin_idx)
        next_bin = Enum.at(bin_used, bin_idx + 1)
        LessOrEqual.new(next_bin, bin)
      end)

    ## TODO: not being used, as it has varying performance effect across instances
    # 2. Arrange bin loads in decreasing order
    ## (only for bins that do not have "over half capacity" items)

    # decreasing_loads =
    #   if num_over_half_capacity + 1 >= num_bins - 1 do
    #     []
    #   else
    #     for i <- (num_over_half_capacity + 1)..num_bins - 1 do
    #       LessOrEqual.new(Enum.at(bin_load, i), Enum.at(bin_load, i - 1))
    #     end
    #   end

    [
      used_bins_first,
      # decreasing_loads
    ]
  end

  def check_solution(
        %{solutions: solutions, variables: variable_names} = _result,
        item_weights,
        capacity
      ) do
    item_weights = Enum.sort(item_weights, :desc)

    Enum.all?(solutions, fn sol ->
      check_solution(sol, item_weights, capacity, variable_names)
    end)
  end

  def check_solution(solution, item_weights, capacity, variable_names) do
    item_assignments =
      Enum.zip(solution, variable_names)
      |> Enum.flat_map(fn {value, variable_name} ->
        if is_binary(variable_name) && String.starts_with?(to_string(variable_name), "x_") do
          value
        end
        |> List.wrap()
      end)

    %{loads: bin_loads, bin_contents: bin_contents} =
      solution_to_bin_content(item_assignments, item_weights)

    ## Loads do no exceed max capacity
    true = Enum.all?(bin_loads, fn l -> l <= capacity end)
    ## All items are placed into bins
    all_item_indices =
      Enum.reduce(tl(bin_contents), hd(bin_contents) |> MapSet.new(), fn bin_items, acc ->
        MapSet.union(acc, MapSet.new(bin_items))
      end)

    true = all_item_indices == MapSet.new(1..length(item_weights))

    ## The total sum of bin weights equals the total sum of item weights
    true = Enum.sum(item_weights) == Enum.sum(bin_loads)
  end

  def solution_to_bin_content(item_assignments, item_weights) do
    bin_contents =
      Enum.group_by(Enum.with_index(item_assignments, 1), fn {val, _} -> val end, fn {_, idx} ->
        idx
      end)

    loads =
      Map.new(bin_contents, fn {bin, content} ->
        {
          bin,
          Enum.sum_by(content, fn item_id -> Enum.at(item_weights, item_id - 1) end)
        }
      end)

    %{loads: Map.values(loads), bin_contents: Map.values(bin_contents)}
  end

  def model(item_weights, capacity, upper_bound, type \\ :minimize)

  def model(item_weights, capacity, upper_bound, :minimize),
    do: minimization_model(item_weights, capacity, upper_bound)

  def solution_handler() do
    fn solution ->
      objective =
        solution
        |> Enum.find(fn {var_name, _value} ->
          var_name == "total_bins_used"
        end)
        |> elem(1)

      Logger.warning("total bins: #{objective}")
    end
  end
end
