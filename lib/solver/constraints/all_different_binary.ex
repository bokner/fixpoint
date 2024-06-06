defmodule CPSolver.Constraint.AllDifferent.Binary do
  use CPSolver.Constraint
  alias CPSolver.Propagator.NotEqual

  @impl true
  def propagators(variables) do
    for i <- 0..(length(variables) - 2) do
      for j <- (i + 1)..(length(variables) - 1) do
        NotEqual.new(Enum.at(variables, i), Enum.at(variables, j))
      end
    end
    |> List.flatten()
  end
end
