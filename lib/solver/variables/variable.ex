defmodule CPSolver.Variable do
  defstruct [:id, :name, :space, :domain]
  @type t :: %__MODULE__{id: reference(), name: String.t(), space: any(), domain: any()}

  def new(domain, name \\ nil, space \\ nil) do
    %__MODULE__{id: make_ref(), domain: domain, name: name, space: space}
  end

  def topic(variable) do
    [variable.space, variable.id]
  end

  def bind_variables(space, variables) do
    Enum.map(variables, fn var -> bind(var, space) end)
  end

  def bind(variable, space) do
    Map.put(variable, :space, space)
  end
end
