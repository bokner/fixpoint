defmodule CPSolver.Examples.Reindeers do
  @doc """
  Santa always leaves plans for his elves to determine the order in which the
  reindeer will pull his sleigh. This year, for the European leg of his
  journey, his elves are working to the following schedule, which will form a
  single line of nine reindeer.

  Here are the rules:

    Comet behind Rudolph, Prancer and Cupid
    Blitzen behind Cupid
    Blitzen in front of Donder, Vixen and Dancer
    Cupid in front of Comet, Blitzen and Vixen
    Donder behind Vixen, Dasher and Prancer
    Rudolph behind Prancer
    Rudolph in front of Donder, Dancer and Dasher
    Vixen in front of Dancer and Comet
    Dancer behind Donder, Rudolph and Blitzen
    Prancer in front of Cupid, Donder and Blitzen
    Dasher behind Prancer
    Dasher in front of Vixen, Dancer and Blitzen
    Donder behind Comet and Cupid
    Cupid in front of Rudolph and Dancer
    Vixen behind Rudolph, Prancer and Dasher.

  """
  alias CPSolver.IntVariable, as: Variable
  alias CPSolver.Model
  alias CPSolver.Constraint.Less
  alias CPSolver.Constraint.AllDifferent.FWC, as: AllDifferent

  def solve(opts \\ []) do
    {:ok, res} = CPSolver.solve_sync(model(), opts)

    res.solutions
    |> hd
    |> then(fn solution -> Enum.zip(res.variables, solution) end)
    |> print()

    {:ok, res}
  end

  def model() do
    reindeers = [
      Blitzen,
      Comet,
      Cupid,
      Dancer,
      Dasher,
      Donder,
      Prancer,
      Rudolph,
      Vixen
    ]

    domain = 1..length(reindeers)

    positions =
      [blitzen, comet, cupid, dancer, dasher, donder, prancer, rudolph, vixen] =
      Enum.map(reindeers, fn name -> Variable.new(domain, name: name) end)

    rules =
      behind(comet, [rudolph, prancer, cupid]) ++
        behind(blitzen, [cupid]) ++
        in_front_of(blitzen, [donder, vixen, dancer]) ++
        in_front_of(cupid, [comet, blitzen, vixen]) ++
        behind(donder, [vixen, dasher, prancer]) ++
        behind(rudolph, [prancer]) ++
        in_front_of(rudolph, [donder, dancer, dasher]) ++
        in_front_of(vixen, [dancer, comet]) ++
        behind(dancer, [donder, rudolph, blitzen]) ++
        in_front_of(prancer, [cupid, donder, blitzen]) ++
        behind(dasher, [prancer]) ++
        in_front_of(dasher, [vixen, dancer, blitzen]) ++
        behind(donder, [comet, cupid]) ++
        in_front_of(cupid, [rudolph, dancer]) ++
        behind(vixen, [rudolph, prancer, dasher])

    Model.new(
      positions,
      ## AllDifferent constraint is optional
      [AllDifferent.new(positions) | rules]
    )
  end

  defp behind(reindeer, list) do
    Enum.map(list, fn r -> Less.new(reindeer, r) end)
  end

  defp in_front_of(reindeer, list) do
    Enum.map(list, fn r -> Less.new(r, reindeer) end)
  end

  def order(solution) do
    solution
    |> Enum.sort_by(fn {_r, place} -> place end)
    |> Enum.map(fn {r, _place} -> r end)
  end

  def print(solution) do
    solution
    |> order
    |> Enum.map_join(" ", fn name -> inspect(name) end)
    |> then(fn str -> IO.ANSI.magenta() <> " -> #{str} ->" <> IO.ANSI.reset() end)
    |> IO.puts()
  end
end
