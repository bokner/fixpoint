alias CPSolver.IntVariable
alias CPSolver.Constraint.NotEqual

x = IntVariable.new([1, 2])
y = IntVariable.new([0, 1])

model = %{
  variables: [x, y],
  constraints: [{NotEqual, x, y}]
}

{:ok, solver} = CPSolver.solve(model)
