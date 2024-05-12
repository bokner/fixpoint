defmodule CPSolver.Variable.View do
  alias CPSolver.Variable
  alias CPSolver.DefaultDomain, as: Domain
  alias __MODULE__, as: View

  defstruct [:mapper, :variable]

  @type t :: %__MODULE__{
          mapper: function(),
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
      ## Given value from variable domain, returns mapped value from view domain
      value when is_integer(value) ->
        a * value + b

      ## Given value from view domain, returns mapped value from variable domain,
      ## or nil, if no mapping exists.
      {value, :inverse} when is_integer(value) ->
        (rem(value - b, a) == 0 && div(value - b, a)) || nil

      ## (Used by removeAbove and removeBelow operations)
      ## Given value from view domain, computes the closest integer value
      ## implied by mapping function, and the operation to be applied.
      {value, :above} when a > 0 ->
        {floor((value - b) / a), :removeAbove}

      {value, :above} when a < 0 ->
        {ceil((value - b) / a), :removeBelow}

      {value, :below} when a > 0 ->
        {ceil((value - b) / a), :removeBelow}

      {value, :below} when a < 0 ->
        {floor((value - b) / a), :removeAbove}

      ## Used by min and max to decide if the operation has to be flipped
      :flip? ->
        a < 0
    end

    %View{variable: variable, mapper: mapper_fun}
  end

  def domain(%{mapper: mapper_fun, variable: variable} = _view) do
    Variable.domain(variable)
    |> Domain.map(mapper_fun)
  end

  def size(%{variable: variable} = _view) do
    Variable.size(variable)
  end

  def fixed?(%{variable: variable} = _view) do
    Variable.fixed?(variable)
  end

  def min(%{mapper: mapper_fun, variable: variable} = _view) do
    domain_value = (mapper_fun.(:flip?) && Variable.max(variable)) || Variable.min(variable)
    mapper_fun.(domain_value)
  end

  def max(%{mapper: mapper_fun, variable: variable} = _view) do
    domain_value = (mapper_fun.(:flip?) && Variable.min(variable)) || Variable.max(variable)
    mapper_fun.(domain_value)
  end

  def contains?(%{mapper: mapper_fun, variable: variable} = _view, value) do
    source_value = mapper_fun.({value, :inverse})
    source_value && Variable.contains?(variable, source_value)
  end

  def remove(%{mapper: mapper_fun, variable: variable} = _view, value) do
    source_value = mapper_fun.({value, :inverse})
    (source_value && Variable.remove(variable, source_value)) || :no_change
  end

  def fix(%{mapper: mapper_fun, variable: variable} = _view, value) do
    source_value = mapper_fun.({value, :inverse})
    (source_value && Variable.fix(variable, source_value)) || :fail
  end

  def removeAbove(%{mapper: mapper_fun, variable: variable} = _view, value) do
    {source_value, operation} = mapper_fun.({value, :above})
    apply(Variable, operation, [variable, source_value])
  end

  def removeBelow(%{mapper: mapper_fun, variable: variable} = _view, value) do
    {source_value, operation} = mapper_fun.({value, :below})
    apply(Variable, operation, [variable, source_value])
  end
end

defmodule CPSolver.Variable.View.Factory do
  import CPSolver.Variable.View
  alias CPSolver.Variable
  alias CPSolver.IntVariable

  def minus(%Variable{} = var) do
    mul(var, -1)
  end

  def mul(%Variable{} = var, coefficient) do
    linear(var, coefficient, 0)
  end

  def linear(_var, 0, offset) do
    IntVariable.new(offset)
  end

  def linear(%Variable{} = var, coefficient, offset)
      when is_integer(coefficient) and
             is_integer(offset) do
    new(var, coefficient, offset)
  end
end
