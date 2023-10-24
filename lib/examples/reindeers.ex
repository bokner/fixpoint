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
  alias CPSolver.Constraint.LessOrEqual
  alias CPSolver.Constraint.AllDifferent

  def solve(opts \\ []) do
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

    model = %{
      variables: positions,
      ## AllDifferent is optional
      constraints: [AllDifferent.new(positions) | rules]
    }

    {:ok, _solver} =
      CPSolver.solve(model,
        solution_handler: Keyword.get(opts, :solution_handler, &print/1)
      )
  end

  defp behind(reindeer, list) do
    Enum.map(list, fn r -> LessOrEqual.new(reindeer, r, -1) end)
  end

  defp in_front_of(reindeer, list) do
    Enum.map(list, fn r -> LessOrEqual.new(r, reindeer, -1) end)
  end

  defp print(solution) do
    solution
    |> Enum.sort_by(fn {_r, place} -> place end)
    |> Enum.map(fn {r, _place} -> inspect(r) end)
    |> Enum.join(" ")
    |> then(fn str -> " -> #{str} ->" end)
    |> IO.puts()
  end
end
