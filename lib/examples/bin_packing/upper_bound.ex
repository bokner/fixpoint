defmodule CPSolver.Examples.BinPacking.UpperBound do
  @moduledoc """
  Precompute upper bounds for bin packing instance
  based on heuristics.
  'First fit decreasing' is the one that is implemented
  """
  alias InPlace.Array

  def first_fit_decreasing(weights, capacity) do
    first_fit(Enum.sort(weights, :desc), capacity)
  end

  def first_fit(weights, capacity) do
    if hd(weights) > capacity do
      throw(:item_weight_over_capacity)
    end

    remaining_bin_space = Array.new(length(weights), capacity)

    ## Map bin_idx => set_of_item_ids
    bins = Map.new()

    weights
    |> Enum.with_index(1)
    |> Enum.reduce({1, bins}, fn {w, item_idx}, {bin_number_acc, bins_content_acc} ->
      if place_item(remaining_bin_space, w, bin_number_acc) do
        {bin_number_acc, Map.update(bins_content_acc, bin_number_acc, MapSet.new([item_idx]),
          fn s -> MapSet.put(s, item_idx) end
        )
      }
      else
        bin_number_acc =
        bin_number_acc + 1
        |> tap(fn new_bin_idx ->
          Array.update(remaining_bin_space, new_bin_idx, fn val -> val - w end)
        end)

        {bin_number_acc, Map.put(bins_content_acc, bin_number_acc, MapSet.new([item_idx]))}
      end
    end)
  end

  defp place_item(bin_space, weight, bin_count) do
    Enum.reduce_while(1..bin_count, false, fn bin_idx, _acc ->
      if Array.get(bin_space, bin_idx) >= weight do
        ## Can place item to this bin
        Array.update(bin_space, bin_idx, fn val -> val - weight end)
        {:halt, true}
      else
        {:cont, false}
      end
    end)
  end
end
