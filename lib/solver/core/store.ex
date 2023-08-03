defmodule CPSolver.ConstraintStore do
  #################
  def default_backend() do
    CPSolver.Store.ETS
  end

  ### API

  ## Tell basic constraints (a.k.a, domains) to a constraint store
  def create(space, variables, opts \\ []) do
  end

  def get_variable(variable, store) do
  end

  defp variable_topic(variable, space) do
    {space, variable}
  end
end
