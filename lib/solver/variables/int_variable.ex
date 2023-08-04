defmodule CPSolver.IntVariable do
  use CPSolver.Variable
  alias CPSolver.Variable

  @impl true
  def size(%Variable{domain: domain}) do
    :gb_sets.size(domain)
  end
end
