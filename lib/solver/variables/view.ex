defmodule CPSolver.Variable.View do
  alias CPSolver.Variable
  alias CPSolver.DefaultDomain, as: Domain
  alias __MODULE__, as: View

  defstruct [:view, :variable]

  @type t :: %__MODULE__{
          view: function(),
          variable: Variable.t()
        }
  @doc """
    Configures (ax + b) view on variable x.
    `mapper_fun` maps view values back to the source variable;
    returns nil if there is no mapping.
  """
  @spec new(Variable.t(), neg_integer() | pos_integer(), integer()) :: View.t()
  def new(variable, a, b) do
    mapper_fun = fn
      ## Given value from view domain, returns mapped value from variable domain,
      ## or nil, if no mapping exists.
      value when is_integer(value) ->
        (rem(value - b, a) == 0 && div(value - b, a)) || nil

      ## (Used by removeAbove and removeBelow operations)
      ## Given value from view domain, computes the closest integer value
      ## implied by mapping function.
      ## The caller will change the operation to an opposite, if 2nd element of
      ## the return is 'true'.
      {value, operation} when operation in [:min, :max, :above, :below] ->
        {div(value - b, a), a < 0}

      ## Used by min and max to decide if the operation has to be flipped
      :flip? ->
        a < 0

      :fail ->
        :fail
    end

    %View{variable: variable, view: mapper_fun}
  end

  def domain(%{view: mapper_fun, variable: variable} = _view) do
    Variable.domain(variable)
    |> Domain.map(mapper_fun)
  end

  def size(%{variable: variable} = _view) do
    Variable.size(variable)
  end

  def fixed?(%{variable: variable} = _view) do
    Variable.fixed?(variable)
  end

  def min(%{view: mapper_fun, variable: variable} = _view) do
    domain_value = (mapper_fun.(:flip?) && Variable.max(variable)) || Variable.min(variable)
    mapper_fun.(domain_value)
  end

  def max(%{view: mapper_fun, variable: variable} = _view) do
    domain_value = (mapper_fun.(:flip?) && Variable.min(variable)) || Variable.max(variable)
    mapper_fun.(domain_value)
  end

  def contains?(%{view: mapper_fun, variable: variable} = _view, value) do
    source_value = mapper_fun.(value)
    source_value && Variable.contains?(variable, source_value)
  end

  def remove(%{view: mapper_fun, variable: variable} = _view, value) do
    source_value = mapper_fun.(value)
    (source_value && Variable.remove(variable, source_value)) || :no_change
  end

  def fix(%{view: mapper_fun, variable: variable} = _view, value) do
    source_value = mapper_fun.(value)
    (source_value && Variable.fix(variable, source_value)) || :fail
  end

  def removeAbove(%{view: mapper_fun, variable: variable} = _view, value) do
    {source_value, flip?} = mapper_fun.({value, :above})

    (flip? && Variable.removeBelow(variable, source_value)) ||
      Variable.removeAbove(variable, source_value)
  end

  def removeBelow(%{view: mapper_fun, variable: variable} = _view, value) do
    {source_value, flip?} = mapper_fun.({value, :below})

    (flip? && Variable.removeAbove(variable, source_value)) ||
      Variable.removeBelow(variable, source_value)
  end
end

defmodule CPSolver.Variable.View.Factory do
  import CPSolver.Variable.View
  alias CPSolver.Variable

  def minus(%Variable{} = var) do
    linear(var, -1, 0)
  end

  def mul(%Variable{} = var) do
    linear(var, 2, 0)
  end

  def linear(%Variable{} = var, coefficient, offset) when is_integer(coefficient) and
      is_integer(offset) and
      coefficient != 0 do
    new(var, coefficient, offset)
  end
end
