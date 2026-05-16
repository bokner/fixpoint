defmodule CPSolver.Search.VariableSelector.FirstFail do
  use CPSolver.Search.VariableSelector
  alias CPSolver.Variable.Interface
  alias CPSolver.Search.Utils, as: SearchUtils

  @impl true
  def select(data, _opts) do
    SearchUtils.minimals(data, &Interface.size/1)
  end

end
