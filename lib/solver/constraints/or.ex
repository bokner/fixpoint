defmodule CPSolver.Constraint.Or do
  @moduledoc """
  ElementVar constrains list of variables `array`, variables `x` and `y` such that:
  array[x] = y

  array is a list of variables
  """
  use CPSolver.Constraint
  alias CPSolver.Propagator.Or, as: OrPropagator
  alias CPSolver.IntVariable, as: Variable

  @impl true
  def propagators(args) do
    [OrPropagator.new(args)]
  end

  @impl true
  def arguments(array) when is_list(array) do
    Enum.map(array, &Variable.to_variable/1)
  end
end
