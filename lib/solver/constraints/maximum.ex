defmodule CPSolver.Constraint.Maximum do
  @moduledoc """
  'Maximum' constraint:
  y = max[x_array]

  x_array is a list of variables
  """

  use CPSolver.Constraint
  alias CPSolver.Propagator.Maximum, as: MaximumPropagator
  alias CPSolver.IntVariable, as: Variable

  @spec new(Variable.variable_or_view(), [Variable.variable_or_view()]) :: Constraint.t()

  def new(c, x_array) when is_integer(c) do
    new(Variable.new(c), x_array)
  end

  def new(y, x_array) do
    new([y | x_array])
  end

  @impl true
  def propagators([_max_var | _var_list] = vars) do
    [MaximumPropagator.new(vars)]
  end
end
