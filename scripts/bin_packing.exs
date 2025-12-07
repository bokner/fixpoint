alias CPSolver.Examples.BinPacking
alias CPSolver.Solver

item_sizes = [4, 7, 2, 6]
num_bins = 3
bin_capacity = 10

# Feasibility
model = BinPacking.feasibility_model(item_sizes, num_bins, bin_capacity)
{:ok, solution} = Solver.solve(model)
IO.inspect(solution)

# Minimization
min_model = BinPacking.minimization_model(item_sizes, num_bins, bin_capacity)
{:ok, min_solution} = Solver.solve(min_model)
IO.inspect(min_solution)
