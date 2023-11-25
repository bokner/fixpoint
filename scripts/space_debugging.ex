alias CPSolver.IntVariable, as: Variable
alias CPSolver.Space, as: Space
alias CPSolver.Propagator.NotEqual
alias CPSolver.Solution
alias CPSolver.Shared

x_values = 1..2
y_values = 1..2
z_values = 1..2
values = [x_values, y_values, z_values]
[x, y, z] = variables = Enum.map(values, fn d -> Variable.new(d) end)
propagators = [NotEqual.new(x, y), NotEqual.new(y, z)]

space_opts = [
  store: CPSolver.ConstraintStore.default_store(),
  solution_handler: Solution.default_handler(),
  search: CPSolver.Search.Strategy.default_strategy()
]

{:ok, space} =
  Space.create(
    variables,
    propagators,
    space_opts
    |> Keyword.put(:solver_data, Shared.init_shared_data(self()))
    |> Keyword.put(:keep_alive, true)
  )
