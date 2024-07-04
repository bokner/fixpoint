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

  ## Choose a "stronger" domain change
  ## from two.
  ## "Stronger" domain change implies the weaker one.
  ## For instance,
  ## - :bound_change implies :domain_change;
  ## - :fixed implies all domain changes.
  ## - :domain_change implies no other domain changes.
  def stronger_domain_change(nil, new_change) do
    new_change
  end

  def stronger_domain_change(:fixed, _new_change) do
    :fixed
  end

  def stronger_domain_change(_current_change, :fixed) do
    :fixed
  end

  def stronger_domain_change(:domain_change, new_change) do
    new_change
  end

  def stronger_domain_change(current_change, :domain_change) do
    current_change
  end

  def stronger_domain_change(:bound_change, bound_change)
      when bound_change in [:min_change, :max_change] do
    bound_change
  end

  def stronger_domain_change(bound_change, :bound_change)
      when bound_change in [:min_change, :max_change] do
    bound_change
  end

  def stronger_domain_change(:min_change, :max_change) do
    :bound_change
  end

  def stronger_domain_change(:max_change, :min_change) do
    :bound_change
  end

  def stronger_domain_change(current_change, new_change) when current_change == new_change do
    current_change
  end
end
