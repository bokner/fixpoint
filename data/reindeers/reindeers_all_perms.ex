
defmodule ReindeersAllPerm do
  ## Generate-and-test solution
  @deer ~w[comet rudolph prancer cupid blitzen donder vixen dancer dasher]a

  def permutations([]), do: [[]]

  def permutations(list),
    do: for(elem <- list, rest <- permutations(list -- [elem]), do: [elem | rest])

  def solve() do
    for possible_permutation <- permutations(@deer),
        p = possible_permutation |> Enum.with_index() |> Map.new(),
        p.comet > p.prancer,
        p.comet > p.rudolph,
        p.comet > p.cupid,
        p.blitzen > p.cupid,
        p.blitzen < p.donder,
        p.blitzen < p.vixen,
        p.blitzen < p.dancer,
        p.donder > p.vixen,
        p.donder > p.dasher,
        p.donder > p.prancer,
        p.rudolph > p.prancer,
        p.rudolph < p.donder,
        p.rudolph < p.dancer,
        p.rudolph < p.dasher,
        p.vixen < p.dancer,
        p.vixen < p.comet,
        p.dancer > p.donder,
        p.dancer > p.rudolph,
        p.dancer > p.blitzen,
        p.prancer < p.cupid,
        p.prancer < p.donder,
        p.prancer < p.blitzen,
        p.dasher > p.prancer,
        p.dasher < p.vixen,
        p.dasher < p.dancer,
        p.dasher < p.blitzen,
        p.donder > p.comet,
        p.donder > p.cupid,
        p.cupid < p.rudolph,
        p.cupid < p.dancer,
        p.vixen > p.rudolph,
        p.vixen > p.prancer,
        p.vixen > p.dasher do
      possible_permutation
    end
  end
end
