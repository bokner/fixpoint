defmodule CPSolver.Examples.StableMarriage do
  @doc """
    Stable marriage problem.
    https://en.wikipedia.org/wiki/Stable_marriage_problem.

  """
  alias CPSolver.IntVariable, as: Variable
  alias CPSolver.Model
  alias CPSolver.Constraint.{ElementVar, Less}
  alias CPSolver.Constraint.Factory, as: ConstraintFactory
  alias CPSolver.Constraint.AllDifferent.DC, as: AllDifferent

  def instances() do
    %{
      van_hentenryck: %{
        rankWomen: [
          [1, 2, 4, 3, 5],
          [3, 5, 1, 2, 4],
          [5, 4, 2, 1, 3],
          [1, 3, 5, 4, 2],
          [4, 2, 3, 5, 1]
        ],
        rankMen: [
          [5, 1, 2, 4, 3],
          [4, 1, 3, 2, 5],
          [5, 3, 2, 4, 1],
          [1, 5, 4, 3, 2],
          [4, 3, 2, 1, 5]
        ]
      },
      # http://mathworld.wolfram.com/StableMarriageProblem.html
      mathworld: %{
        rankWomen: [
          [3, 1, 5, 2, 8, 7, 6, 9, 4],
          [9, 4, 8, 1, 7, 6, 3, 2, 5],
          [3, 1, 8, 9, 5, 4, 2, 6, 7],
          [8, 7, 5, 3, 2, 6, 4, 9, 1],
          [6, 9, 2, 5, 1, 4, 7, 3, 8],
          [2, 4, 5, 1, 6, 8, 3, 9, 7],
          [9, 3, 8, 2, 7, 5, 4, 6, 1],
          [6, 3, 2, 1, 8, 4, 5, 9, 7],
          [8, 2, 6, 4, 9, 1, 3, 7, 5]
        ],
        rankMen: [
          [7, 3, 8, 9, 6, 4, 2, 1, 5],
          [5, 4, 8, 3, 1, 2, 6, 7, 9],
          [4, 8, 3, 9, 7, 5, 6, 1, 2],
          [9, 7, 4, 2, 5, 8, 3, 1, 6],
          [2, 6, 4, 9, 8, 7, 5, 1, 3],
          [2, 7, 8, 6, 5, 3, 4, 1, 9],
          [1, 6, 2, 3, 8, 5, 4, 9, 7],
          [5, 6, 9, 1, 2, 8, 4, 3, 7],
          [6, 1, 4, 7, 5, 8, 3, 9, 2]
        ]
      },
      problem3: %{
        rankWomen: [
          [1, 2, 3, 4],
          [4, 3, 2, 1],
          [1, 2, 3, 4],
          [3, 4, 1, 2]
        ],
        rankMen: [
          [1, 2, 3, 4],
          [2, 1, 3, 4],
          [1, 4, 3, 2],
          [4, 3, 1, 2]
        ]
      },
      problem4: %{
        rankWomen:
          [[1, 5, 4, 6, 2, 3], [4, 1, 5, 2, 6, 3], [6, 4, 2, 1, 5, 3], [1, 5, 2, 4, 3, 6],
           [4, 2, 1, 5, 6, 3], [2, 6, 3, 5, 1, 4]],
        rankMen:
          [[1, 4, 2, 5, 6, 3], [3, 4, 6, 1, 5, 2], [1, 6, 4, 2, 3, 5], [6, 5, 3, 4, 2, 1],
           [3, 1, 2, 4, 5, 6], [2, 3, 1, 6, 5, 4]]
      }
    }
  end

  def solve(instance, opts \\ []) do
    {:ok, res} = CPSolver.solve(model(instance), opts)

    res.solutions
    |> Enum.each(fn solution ->
      Enum.zip(res.variables, solution)
      |> print(instance_dimension(instances()|>
      Map.get(instance)))
    end)


    {:ok, res}
  end

  def model(instance) do
    data = Map.get(instances(), instance)
    dim = instance_dimension(data)
    range = 0..dim-1
    wife = Enum.map(range, fn i -> Variable.new(range, name: "wife#{i+1}") end)
    husband = Enum.map(range, fn i -> Variable.new(range, name: "husband#{i+1}") end)
    ## Bijection (1-to-1) husband <-> wife
    bijections = for h <- range do
      #husband[wife[m]] = m
      ElementVar.new(husband, Enum.at(wife, h), h)
    end ++
    for w <- range do
      #[wife[husband[m]] = m
      ElementVar.new(wife, Enum.at(husband, w), w)
    end

    pref_constraints = for w <- range, h <- range, reduce: [] do
      constraints_acc ->
      rankMen_h = Map.get(data, :rankMen) |> Enum.at(h)
      rankMen_h_w = rankMen_h |> Enum.at(w)
      {rankMen_h_w_var, elementRankMen} = ConstraintFactory.element(rankMen_h, Enum.at(wife, h))

      rankWomen_w = Map.get(data, :rankWomen) |> Enum.at(w)
      rankWomen_w_h = rankWomen_w |> Enum.at(h)
      {rankWomen_w_h_var, elementRankWomen} = ConstraintFactory.element(rankWomen_w, Enum.at(husband,w))

      impl_submodel = ConstraintFactory.impl(
        Less.new([rankMen_h_w, rankMen_h_w_var]),
        Less.new([rankWomen_w_h_var, rankWomen_w_h]))

      constraints_acc ++
        impl_submodel.constraints ++
        [elementRankMen, elementRankWomen]

      end
      |> List.flatten

    Model.new(wife ++ husband,
    bijections ++ pref_constraints ++ [AllDifferent.new(husband), AllDifferent.new(wife)] )

  end

  defp instance_dimension(data) do
    Map.get(data, :rankWomen) |> length
  end

  def print(solution, n) do
    IO.puts("\n")
      solution
      |> Enum.take(n)
      |> Enum.with_index(0)
      |> Enum.each(fn {{_wife_name, h}, w} -> IO.puts("\u2640:#{w+1} #{IO.ANSI.red}\u26ad#{IO.ANSI.reset} #{h+1}:\u2642") end)
  end

  @doc """
    Pseudocode for checking stability
    (https://stackoverflow.com/questions/58439880/algorithm-to-verify-stable-matching)

      for w in women:
          for m in [men w would prefer over current_partner(w)]:
              if m prefers w to current_partner(m) return false

      return true
  """
  def check_solution(solution, instance) do
    data = instances()[instance]
    women_prefs = Map.get(data, :rankWomen)
    men_prefs = Map.get(data, :rankMen)
    n = instance_dimension(data)
    {women_assignments, men_assignments} = Enum.take(solution, 2*n) |> Enum.split(n)
    men_lookup = Enum.with_index(men_assignments, 0) |> Map.new(fn {partner, idx} -> {idx, partner} end)

    women_assignments
    |> Enum.with_index(0)
    |> Enum.take(1)
    |> Enum.all?(fn {current_partner, w} ->
      w_prefs = Enum.at(women_prefs, w) |> Enum.map(fn p -> p - 1 end)
      current_partner_rank = Enum.find_index(w_prefs, fn p -> p == current_partner end)
      ## Walk over candidates with higher ranks.
      ## If any of candidates prefers w over his current partner, stability doesn't hold
      Enum.take(w_prefs, current_partner_rank)
      |> Enum.all?(fn candidate ->
        candidate_prefs = Enum.at(men_prefs, candidate) |> Enum.map(fn p -> p - 1 end)
        candidate_current_partner = Map.get(men_lookup, candidate)
        candidate_current_partner_rank = Enum.find_index(candidate_prefs, fn p -> p == candidate_current_partner end)
        candidate_w_rank = Enum.find_index(candidate_prefs, fn p -> p == w end)
        ## Candidate prefers current partner to w
        candidate_w_rank < candidate_current_partner_rank
      end)


    end)

  end
end
