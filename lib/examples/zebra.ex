defmodule CPSolver.Examples.Zebra do
  @moduledoc """
  https://en.wikipedia.org/wiki/Zebra_Puzzle

  There are five houses.
  The Englishman lives in the red house.
  The Spaniard owns the dog.
  Coffee is drunk in the green house.
  The Ukrainian drinks tea.
  The green house is immediately to the right of the ivory house.
  The Old Gold smoker owns snails.
  Kools are smoked in the yellow house.
  Milk is drunk in the middle house.
  The Norwegian lives in the first house.
  The man who smokes Chesterfields lives in the house next to the man with the fox.
  Kools are smoked in the house next to the house where the horse is kept.
  The Lucky Strike smoker drinks orange juice.
  The Japanese smokes Parliaments.
  The Norwegian lives next to the blue house.
  Now, who drinks water? Who owns the zebra?
  """

  @doc """
  The model is a clone of MiniZinc model
  (https://github.com/hakank/hakank/blob/39a2b9e868011df38bd7c90f530f8c5b3e0740cb/minizinc/zebra_inverse.mzn)
  by Håkan Kjellerstrand
  """
  alias CPSolver.IntVariable, as: Variable
  alias CPSolver.Model
  import CPSolver.Constraint.Factory
  import CPSolver.Variable.View.Factory

  def model() do
    ### Variables
    domain = 0..4
    color_vars = [red, green, ivory, yellow, blue] =
      create_vars([:red, :green, :ivory, :yellow, :blue], domain)
    nationality_vars = [englishman, spaniard, ukrainian, norwegian, japanese] =
      create_vars([:englishman, :spaniard, :ukrainian, :norwegian, :japanese], domain)
    animal_vars = [dog, snail, fox, horse, _zebra] =
      create_vars([:dog, :snail, :fox, :horse, :zebra], domain)
    drink_vars = [coffee, tea, milk, orange_juice, _water] =
      create_vars([:coffee, :tea, :milk, :orange_juice, :water], domain)
    brand_vars = [old_gold, kool, chesterfield, lucky_strike, parliament] =
      create_vars([:old_gold, :kool, :chesterfield, :lucky_strike, :parliament], domain)

    ### Constraints
    inverse_constraints = Enum.map(
      [color_vars, nationality_vars, animal_vars, drink_vars, brand_vars],
      fn vars ->
        inverse(create_tmp_vars(domain), vars)
      end
    )
    constraints =
      [
        equal(englishman, red),
        equal(spaniard, dog),
        equal(coffee, green),
        equal(ukrainian, tea),
        equal(green, inc(ivory, 1)),
        equal(old_gold, snail),
        equal(kool, yellow),
        equal(milk, house(3)),
        equal(norwegian, house(1)),
        next_to(chesterfield, fox),
        next_to(kool, horse),
        equal(lucky_strike, orange_juice),
        equal(japanese, parliament),
        next_to(norwegian, blue),
        inverse_constraints
      ]

      Model.new(
        color_vars ++ nationality_vars ++ animal_vars ++ drink_vars ++ brand_vars,
        constraints
      )
  end


  def solve(opts \\ []) do
    CPSolver.solve(model(), opts)
  end

  defp create_tmp_vars(domain) do
    Enum.map(1..5, fn _ -> Variable.new(domain) end)
  end

  defp create_vars(names, domain) do
    Enum.map(names, fn name -> Variable.new(domain, name: name) end)
  end

  defp next_to(var1, var2) do
      {tmp, c} = subtract(var1, var2)
      [c, absolute(tmp, 1)]
  end

  defp find_match(block1, block2, position_to_match) do
    value_to_match = Enum.at(block2, position_to_match)
    Enum.find_index(block1, fn x -> x == value_to_match end)
  end

  def puzzle_solution(res) do
    solution = hd(res.solutions)
    nationality_names = Enum.slice(res.variables, 5, 5)
    [_colors, nationalities, animals, drinks, _brands] = Enum.chunk_every(solution, 5) |> Enum.take(5)

    zebra_owner = find_match(nationalities, animals, 4)
    water_drinker = find_match(nationalities, drinks, 4)

    %{zebra_owner: Enum.at(nationality_names, zebra_owner),
      water_drinker: Enum.at(nationality_names, water_drinker)
    }
  end

  ## Shift to 0-based
  defp house(number) do
    number - 1
  end
end
