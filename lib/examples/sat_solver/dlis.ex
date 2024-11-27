defmodule CPSolver.SatSolver.VariableSelector.DLIS do
  @moduledoc """
  Dynamic Largest Individual Sum.

  For a given variable x:
– C(x,p) – # of unresolved clauses in which x appears positively
– C(x,n) - # of unresolved clauses in which x appears negatively
– Let x be the literal for which Cx,p is maximal
– Let y be the literal for which Cy,n is maximal
– If Cx,p > Cy,n choose x and assign it TRUE
– Otherwise choose y and assign it FALSE
  """
  use CPSolver.Search.VariableSelector

  @impl true
  def select(_variables, _space_data, _opts) do
    :todo
  end
end
