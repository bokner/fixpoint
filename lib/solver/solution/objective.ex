defmodule CPSolver.Solution.Objective do
  alias CPSolver.Variable
  alias CPSolver.Variable.View
  import CPSolver.Variable.View.Factory

  @spec minimize(Variable.t() | View.t()) :: function()
  def minimize(variable) do
    
  end

  @spec maximize(Variable.t()) :: function()
  def maximize(variable) do
    minimize(minus(variable))
  end
end
