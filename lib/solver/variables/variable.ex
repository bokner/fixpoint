defmodule CPSolver.Variable do
  defstruct [:id, :name, :space, :domain]
  @type t :: %__MODULE__{id: reference(), name: String.t(), space: any(), domain: any()}

  def new(domain, name \\ nil, space \\ nil) do
    %__MODULE__{id: make_ref(), domain: domain, name: name, space: space}
  end
end
