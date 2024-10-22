example = "triangle_uni"

defmodule GraphScript do
  def solve_graph(example, solver_opts \\ []) do
    instance = "data/graph_coloring/#{example}"
    {:ok, solver} = CPSolver.Examples.GraphColoring.solve_async(instance, solver_opts)
  end

  def propagating_spaces(solver) do
    solver_state = :sys.get_state(solver)

    solver_state.active_nodes
    |> Enum.filter(fn space ->
      Process.alive?(space) &&
        (
          {state, data} = :sys.get_state(space)
          state == :propagating
        )
    end)
  end

  def threads(spaces) do
    Enum.map(spaces, fn pid ->
      {_, data} = :sys.get_state(pid)
      data.propagator_threads
    end)
  end
end

GraphScript.solve_graph(example, solver_opts)
