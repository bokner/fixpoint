example = "triangle_uni"
instance = "data/graph_coloring/#{example}"
{:ok, solver} = CPSolver.Examples.GraphColoring.solve(instance)
stats = CPSolver.statistics(solver)

solver_state = :sys.get_state(solver)

propagating_spaces = solver_state.active_nodes |> Enum.filter(fn space -> Process.alive?(space) && ({state, data} = :sys.get_state(space); state == :propagating) end)

Enum.map(propagating_spaces, fn pid -> {_, data} = :sys.get_state(pid); data.propagator_threads
 end)
