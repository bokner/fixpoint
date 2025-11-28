defmodule CPSolver.Examples.BinPacking do
  @moduledoc """
  Bin Packing Problem Example

  Given:
  - n items, each with weights w[i]

  The goal is to assign each item to a bin such that:
  sum of item weights in each bin <= capacity.

  Optionally: minimize the number of bins used.
  """

  alias CPSolver.IntVariable, as: Variable
  alias CPSolver.Model
  alias CPSolver.Constraint.Sum
  alias CPSolver.Constraint.LessOrEqual
  import CPSolver.Variable.View.Factory
  alias CPSolver.Objective

  def prebuild_model(weights) do
    item_weights = weights
    num_items = length(item_weights)
    bin_capacity = Enum.max(item_weights)

    # worst case one item per bin
    num_bins = num_items

    items_vars =
      Enum.map(1..num_items, fn i -> Variable.new(0..(num_items - 1), name: "x#{i}") end)

    # indicators: 2D array [i][b] is 0 or 1 depending if item i is inside bin b
    indicators =
      for i <- 1..num_items do
        for b <- 1..num_bins do
          Variable.new(0..1, name: "item_#{i}_in_bin_#{b}")
        end
      end

    # variable for total weight in each bin. Domain: 0..SUM(weights)
    total_weights =
      for b <- 0..(num_bins - 1) do
        Variable.new(0..Enum.sum(item_weights), name: "total_weight_bin#{b}")
      end

    %{
      items: items_vars,
      indicators: indicators,
      total_weights: total_weights,
      bin_capacity: bin_capacity
    }
  end

  def feasibility_model(item_weights) do
    %{
      items: items,
      indicators: indicators,
      total_weights: total_weights,
      bin_capacity: bin_capacity
    } = prebuild_model(item_weights)

    link_item_constraints =
      Enum.zip(items, indicators)
      |> Enum.map(fn {item_var, inds} ->
        views = Enum.with_index(inds, 0) |> Enum.map(fn {ind, b} -> mul(ind, b) end)
        Sum.new(item_var, views)
      end)

    one = Variable.new(1..1, name: "one")
    exactly_one = Enum.map(indicators, fn inds -> Sum.new(one, inds) end)

    bin_weight_constraints =
      Enum.with_index(total_weights, 0)
      |> Enum.flat_map(fn {tw, b} ->
        views =
          Enum.with_index(indicators, 1)
          |> Enum.map(fn {inds_for_item, i} ->
            ind = Enum.at(inds_for_item, b)
            mul(ind, Enum.at(item_weights, i - 1))
          end)

        [Sum.new(tw, views), LessOrEqual.new(tw, bin_capacity)]
      end)

    constraints =
      link_item_constraints ++ exactly_one ++ bin_weight_constraints

    vars = items ++ List.flatten(indicators) ++ total_weights

    Model.new(
      vars,
      constraints
    )
  end

  def minimization_model(item_weights) do
    %{
      items: item_vars,
      indicators: indicators,
      total_weights: total_weights,
      bin_capacity: bin_capacity
    } = prebuild_model(item_weights)

    link_item_constraints =
      Enum.zip(item_vars, indicators)
      |> Enum.map(fn {item_var, inds} ->
        views = Enum.with_index(inds, 0) |> Enum.map(fn {ind, b} -> mul(ind, b) end)
        Sum.new(item_var, views)
      end)

    one_var = Variable.new(1..1, name: "one")
    exactly_one_constraints = Enum.map(indicators, fn inds -> Sum.new(one_var, inds) end)

    bin_weight_constraints =
      Enum.with_index(total_weights, 0)
      |> Enum.flat_map(fn {tw, b} ->
        views =
          Enum.with_index(indicators, 1)
          |> Enum.map(fn {inds_for_item, i} ->
            ind = Enum.at(inds_for_item, b)
            mul(ind, Enum.at(item_weights, i - 1))
          end)

        [Sum.new(tw, views), LessOrEqual.new(tw, bin_capacity)]
      end)

    bin_used = Enum.map(total_weights, fn tw -> Variable.new(0..1, name: "#{tw.name}_used") end)

    # link: total_weight <= bin_capacity * bin_used
    link_used_constraints =
      Enum.zip(total_weights, bin_used)
      |> Enum.map(fn {tw, used} -> LessOrEqual.new(tw, mul(used, bin_capacity)) end)

    total_bins_used = Variable.new(0..length(item_weights), name: "total_bins_used")
    Sum.new(total_bins_used, bin_used)

    constraints =
      link_item_constraints ++
        exactly_one_constraints ++
        bin_weight_constraints ++
        link_used_constraints ++
        [Sum.new(total_bins_used, bin_used)]

    vars = item_vars ++ List.flatten(indicators) ++ total_weights ++ bin_used ++ [total_bins_used]

    Model.new(vars, constraints, objective: Objective.minimize(total_bins_used))
  end

  def print_result(result) do
    solution = List.first(CPSolver.solutions(result))

    assignments =
      Enum.zip(result.variable_names, solution)
      |> Enum.filter(fn {name, value} ->
        is_binary(name) and value == 1 and String.starts_with?(name, "item_")
      end)

    items_by_bin =
      Enum.reduce(assignments, %{}, fn {name, _value}, acc ->
        case String.split(name, "_in_bin_") do
          [item, bin] ->
            Map.update(acc, bin, [item], fn items -> [item | items] end)

          _ ->
            acc
        end
      end)

    Enum.each(items_by_bin, fn {bin, items} ->
      IO.puts("Bin #{bin} contains: #{Enum.join(Enum.reverse(items), ", ")}")
    end)
  end

  def model(item_weights, type \\ :feasibility)

  def model(item_weights, :feasibility), do: feasibility_model(item_weights)
  def model(item_weights, :minimize), do: minimization_model(item_weights)
end
