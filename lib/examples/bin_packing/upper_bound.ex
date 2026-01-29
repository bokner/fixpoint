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
    Enum.reduce(weights, 1, fn w, count_acc ->
      if place_item(remaining_bin_space, w, count_acc) do
        count_acc
      else
        (count_acc + 1)
        |> tap(fn new_bin_idx ->
          Array.update(remaining_bin_space, new_bin_idx, fn val -> val - w end)
        end)
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
    #     j = 0
    #     while( j < res):
    #         if (bin_rem[j] >= weight[i]):
    #             bin_rem[j] = bin_rem[j] - weight[i]
    #             break
    #         j+=1

    #     # If no bin could accommodate weight[i]
    #     if (j == res):
    #         bin_rem[res] = c - weight[i]
    #         res= res+1
    # return res


  def test() do
    weights = [ 2, 5, 4, 7, 1, 3, 8 ]
    capacity = 10
    first_fit_decreasing(weights, capacity)
  end

end
