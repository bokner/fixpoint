defmodule CPSolver.Common do
  alias CPSolver.Variable
  alias CPSolver.Variable.View

  @type domain_change :: :fixed | :domain_change | :min_change | :max_change
  @type domain_get_operation :: :size | :fixed? | :min | :max | :contains?
  @type domain_update_operation :: :remove | :removeAbove | :removeBelow | :fix

  @type variable_or_view :: Variable.t() | View.t()

  def domain_events() do
    [:fixed, :domain_change, :min_change, :max_change]
  end

  ## Value for unfixed variables.
  ## Is used by ConstraintStore to track atomic changes for already fixed variables.
  ##
  def unfixed() do
    :atomics.new(1, signed: true)
    |> :atomics.info()
    |> Map.get(:max)
  end
end
