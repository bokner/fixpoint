alias CPSolver.IntVariable
alias CPSolver.Constraint.Less

x = IntVariable.new([0, 1, 2])
y = IntVariable.new([0, 1, 2])

model = %{
  variables: [x, y],
  constraints: [Less.new(x, y)]
}

{:ok, solver} = CPSolver.solve_sync(model)
