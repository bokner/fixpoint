defmodule CPSolver.Search.VariableSelector.FirstFail do
  use CPSolver.Search.VariableSelector
  alias CPSolver.Variable.Interface
  alias CPSolver.Search.Utils, as: SearchUtils

  @impl true
  def select(%{unfixed_variables_tracker: tracker, variables: variables} = _data, _opts) do
    SearchUtils.minimals(tracker, variables, &Interface.size/1)
  end

end
