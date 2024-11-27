defmodule CPSolver.Search.VariableSelector.FirstFail do
  use CPSolver.Search.VariableSelector
  alias CPSolver.Variable.Interface
  alias CPSolver.Utils

  def select(variables, _data \\ %{}, _opts) do
    get_minimals(variables)
  end

  def get_minimals(variables) do
    Utils.minimals(variables, &Interface.size/1)
  end
end
