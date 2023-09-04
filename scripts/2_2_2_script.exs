space_opts = [keep_alive: true]

alias CPSolver.Store.Registry, as: Store
alias CPSolver.IntVariable, as: Variable
alias CPSolver.Space, as: Space
alias CPSolver.Propagator.NotEqual
alias CPSolver.Solution
x_values = 1..2
y_values = 1..2
z_values = 1..2
values = [x_values, y_values, z_values]
[x, y, z] = variables = Enum.map(values, fn d -> Variable.new(d) end)
propagators = [{NotEqual, [x, y]}, {NotEqual, [y, z]}]

{:ok, space} = Space.create(variables, propagators, space_opts)
%{space: space, propagators: propagators, variables: variables, domains: values}
