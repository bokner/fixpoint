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
  alias CPSolver.Search.VariableSelector, as: Strategy
  import CPSolver.Variable.View.Factory
  import CPSolver.Utils

  alias CPSolver.Objective

  alias CPSolver.Examples.BinPacking.UpperBound

  require Logger

  def run(weights, capacity, opts \\ []) do
    upper_bound = Keyword.get(opts, :upper_bound, UpperBound.first_fit_decreasing(weights, capacity))
    model = model(weights, capacity, upper_bound)

    opts =
      Keyword.merge(
        [
          search: model.search,
          solution_handler: solution_handler(),
          timeout: :timer.seconds(30)
        ],
        opts
      )

    Logger.warning("Started")

    {:ok, _res} = CPSolver.solve(model, opts)
  end


  def minimization_model(item_weights, capacity, upper_bound \\ nil) do
    item_weights = Enum.sort(item_weights, :desc)
    num_items = length(item_weights)
    num_items_over_half_capacity = Enum.count(item_weights, fn w -> 2*w > capacity end)
    num_bins = upper_bound || num_items
    lower_bound = max(num_items_over_half_capacity, ceil(Enum.sum(item_weights) / capacity))

    # x[i][j] item i assigned to bin j
    indicators =
      for i <- 1..num_items do
        item_over_half_capacity? = (i <= num_items_over_half_capacity)

        for j <- 1..num_bins do
          domain = if item_over_half_capacity? do
            (i == j && 1 || 0)
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
        d = (i <= lower_bound) && 1 || 0..1
        Variable.new(d, name: "bin_#{i}_used")
      end

    # total weight in bin i
    bin_load =
      for i <- 1..num_bins do
        Variable.new(0..capacity, name: "bin_load_#{i}")
      end

    ###################
    ### Constraints ###
    ###################
    upper_bound_constraint = LessOrEqual.new(total_bins_used, num_bins)

    # item_assignment_constraints =
    #   Enum.map(indicators, fn inds ->
    #     Sum.new(1, inds)
    #   end)

    x = Enum.map(1..num_items, fn idx -> Variable.new(1..num_bins, name: "x_#{idx}") end)
    item_assignment_constraints =
      for i <- 0..num_items-1 do
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
      |> Map.put(:search, search_cdbf(item_weights, x, bin_load))
  end

  defp symmetry_breaking_constraints(bin_used, _bin_load, num_bins, _num_over_half_capacity) do
    # Symmetry breaking
    # 1. Only allow bin j to be used if all bins < j are used.
    # This prevents the solver from seeing equivalent packings as different solutions.
    used_bins_first =
      Enum.map(0..num_bins - 2, fn bin_idx ->
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
      used_bins_first
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

  def check_solution(result, item_weights, capacity) do
    best_solution = result.solutions |> List.last()
    %{loads: bin_loads, bin_contents: bin_contents} =
      solution_to_bin_content(best_solution, item_weights, capacity, result.objective)

    ## Loads do no exceed max capacity
    true = Enum.all?(bin_loads, fn l -> l <= capacity end)
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

  def solution_to_bin_content(solution, item_weights, _capacity, objective) do
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

  def model(item_weights, capacity, upper_bound, type \\ :minimize)

  def model(item_weights, capacity, upper_bound, :minimize),
    do: minimization_model(item_weights, capacity, upper_bound)

  ## Complete decreasing best fit branching
  ## roughly as per
  ## https://www.gecode.dev/doc-latest/MPG.pdf, chapter 20
  ##
  def search_cdbf(item_weights, item_assignment_vars, bin_load_vars) do
    ## Create a list [{item_assignment_index,  item_weight}]
    ## (will be used for matching the item assignment variables with items' weights)
    ##
    ## Note: item weights are sorted in decreasing order
    item_assignment_ids = MapSet.new(item_assignment_vars, fn v -> v.index end)
    item_assignment_list =
      Enum.zip(item_weights, item_assignment_vars)


    choose_variable_fun = fn variables ->
      ## get all (unfixed) item assignment vars
      {item_vars, rest_vars} = Enum.split_with(variables, fn v -> v.index in item_assignment_ids end)

      if Enum.empty?(item_vars) do
        ## All item assignments were made - we're done
        #nil
        Strategy.select_variable(rest_vars, nil, :first_fail)
      else
        ## keep the entries in item assignment list that correspond to unfixed variables.
        hd(item_vars)
      end
    end

    choose_value_fun = fn var ->
      d_values = domain_values(var)
      ## TODO: choose based on variable kind (Enum.max/1 may be better for loads etc...)
      Enum.max(d_values)
    end

    {choose_variable_fun, choose_value_fun}
  end

  # defp cdbf_branching(item_var_choices, bin_load_vars) do
  #   item_var_ids = MapSet.new(item_vars, fn v -> v.id end)

  #   item_choices = Enum.filter(item_assignment_list, fn {weight, item_var} -> item_var.index in item_var_ids end)
  #   Enum.reduce_while(bin_load_vars, {1, []}, fn load_var, {load_idx, choices_acc} ->
  #     {load_idx + 1,
  #      if Variable.fixed?(load_var) do
  #       choices_acc
  #      else
  #       case slack(load_var) do
  #         s when s == item_weight ->
  #           ## Perfect load (the bin will be fully loaded) ->
  #           {:halt, {:single_branch, load_idx}}
  #           end
  #         end
  #     }
  #   end)
  # end

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
