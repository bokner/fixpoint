defmodule CPSolver.Examples.SendMoreMoney do
  @moduledoc """
  The classic "cryptarithmetic" (https://en.wikipedia.org/wiki/Verbal_arithmetic) problem.
  Solve the following (each letter is a separate digit):

  SEND + MORE = MONEY

  """

  alias CPSolver.IntVariable, as: Variable
  alias CPSolver.Model
  alias CPSolver.Constraint.Sum
  alias CPSolver.Constraint.AllDifferent
  import CPSolver.Variable.View.Factory

  def model() do
    letters = [S, E, N, D, M, O, R, Y]

    variables =
      [s, e, n, d, m, o, r, y] =
      Enum.map(letters, fn letter ->
        d = (letter in [S, M] && 1..9) || 0..9
        Variable.new(d, name: letter)
      end)

    sum_constraint =
      Sum.new(y, [
        d,
        mul(n, -90),
        mul(e, 91),
        mul(s, 1000),
        mul(r, 10),
        mul(o, -900),
        mul(m, -9_000)
      ])

    Model.new(variables, [sum_constraint, AllDifferent.new(variables)])
  end

  def solve() do
    {:ok, res} = CPSolver.solve_sync(model(), stop_on: {:max_solutions, 1})
    Enum.zip(res.variables, hd(res.solutions))
  end

  def check_solution([s, e, n, d, m, o, r, y] = _solution) do
    1000 * s + 100 * e + 10 * n + d +
      1000 * m + 100 * o + 10 * r + e ==
      10_000 * m + 1000 * o + 100 * n + 10 * e + y
  end
end
