defmodule CPSolver.Examples.Euler43 do
  @doc """
  int: n = 10;
  array[1..n] of var 0..9: x;
  array[int] of int: primes = [2,3,5,7,11,13,17];
  solve satisfy;
  constraint
    all_different(x) /\
    forall(i in 2..8) (
      (100*x[i] + 10*x[i+1] + x[i+2]) mod primes[i-1] = 0
    )
  ;
  output [ show(x),"\n"];
  """

  alias CPSolver.IntVariable, as: Variable
  alias CPSolver.Constraint.AllDifferent.FWC, as: AllDifferent
  alias CPSolver.Constraint.Modulo
  alias CPSolver.Model
  import CPSolver.Constraint.Factory
  import CPSolver.Variable.View.Factory

  require Logger

  @minizinc_solutions Enum.sort([
                        [4, 1, 6, 0, 3, 5, 7, 2, 8, 9],
                        [1, 4, 6, 0, 3, 5, 7, 2, 8, 9],
                        [4, 1, 0, 6, 3, 5, 7, 2, 8, 9],
                        [1, 4, 0, 6, 3, 5, 7, 2, 8, 9],
                        [4, 1, 3, 0, 9, 5, 2, 8, 6, 7],
                        [1, 4, 3, 0, 9, 5, 2, 8, 6, 7]
                      ])

  def model() do
    primes = [2, 3, 5, 7, 11, 13, 17]
    domain = 0..9

    x = Enum.map(1..10, fn i -> Variable.new(domain, name: "x#{i}") end)

    all_different_constraint = AllDifferent.new(x)

    constraints =
      Enum.reduce(2..8, [all_different_constraint], fn i, constraints_acc ->
        x_i = Enum.at(x, i - 1)
        x_i_1 = Enum.at(x, i)
        x_i_2 = Enum.at(x, i + 1)
        prime = Enum.at(primes, i - 2)
        {sum_var, sum_constraint} = sum([mul(x_i, 100), mul(x_i_1, 10), x_i_2])
        mod_constraint = Modulo.new(0, sum_var, prime)
        [sum_constraint, mod_constraint | constraints_acc]
      end)

    Model.new(x, constraints)
  end

  def check_solution(solution) do
    solution
    |> Enum.take(10)
    |> Kernel.in(@minizinc_solutions)
  end

  def run(opts \\ []) do
    {:ok, res} = CPSolver.solve_sync(model(), opts)

    (Enum.sort(Enum.map(res.solutions, fn s -> Enum.take(s, 10) end)) == @minizinc_solutions &&
       Logger.notice("Solutions correspond to the ones given by MinZinc")) ||
      Logger.error("Solutions do not match MiniZinc")
  end
end
