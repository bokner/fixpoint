alias CPSolver.Constraint
alias CPSolver.Constraint.Less
alias CPSolver.IntVariable, as: Variable
alias CPSolver.ConstraintStore

x = Variable.new(1..2, name: "x")
y = Variable.new(1..2, name: "y")

{:ok, [x_var, y_var] = bound_vars, store} = ConstraintStore.create_store([x, y])

Constraint.post(Less.new(x_var, y_var))
