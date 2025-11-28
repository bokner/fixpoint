defmodule CPSolver.Examples.BinPacking do
  @moduledoc """
  Bin Packing Problem Example

  Given:
  - n items, each with weights s[i]
  - a fixed number of bins, each with capacity c

  The goal is to assign each item to a bin such that:
  sum of item sizes in each bin <= c

  Optionally, minimize the number of bins used.
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

    # variable for total weight in each bin. Domain: 0..SUM(weights)
    total_weights =
      Enum.map(0..(num_bins - 1), fn b ->
        Variable.new(0..Enum.sum(item_weights), name: "total_weight_bin#{b}")
      end)

    weight_views_per_bin =
      for bin <- 0..(num_bins - 1) do
        Enum.zip(items_vars, item_weights)
        |> Enum.map(fn {item, weight} -> mul(eq(item, bin), weight) end)
      end

    %{
      items: items_vars,
      total_weights: total_weights,
      weight_views_per_bin: weight_views_per_bin,
      bin_capacity: bin_capacity
    }
  end

  def feasibility_model(item_weights) do
    %{
      items: items,
      total_weights: total_weights,
      weight_views_per_bin: weight_views_per_bin,
      bin_capacity: bin_capacity
    } = prebuild_model(item_weights)

    constraints =
      Enum.zip(total_weights, weight_views_per_bin)
      |> Enum.flat_map(fn {total_weights, views} ->
        [
          Sum.new(total_weights, views),
          LessOrEqual.new(total_weights, bin_capacity)
        ]
      end)

    Model.new(
      items ++ total_weights,
      constraints
    )
  end

  def model(item_weights), do: model(item_weights, :feasibility)

  def model(item_weights, :feasibility), do: feasibility_model(item_weights)
end
