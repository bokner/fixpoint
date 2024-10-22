defmodule OR do
  alias CPSolver.BooleanVariable
  alias CPSolver.Model
  alias CPSolver.Constraint.Or

  def test(n) do
  bool_vars = Enum.map(1..n, fn i -> BooleanVariable.new(name: "b#{i}") end)
  or_constraint = Or.new(bool_vars)

  model = Model.new(bool_vars, [or_constraint])

  CPSolver.solve(model, stop_on: {:max_solutions, 1}, search: {:first_fail, :indomain_max}, space_threads: 1, solution_handler: fn sol -> IO.inspect("Done") end)
  #IO.inspect(result)
  end
end
