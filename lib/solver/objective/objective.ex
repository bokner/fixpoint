defmodule CPSolver.Objective do
  alias CPSolver.Objective.Propagator, as: ObjectivePropagator
  alias CPSolver.Variable.Interface
  import CPSolver.Variable.View.Factory

  @spec minimize(Variable.t() | View.t()) :: %{
          :propagator => Propagator.t(),
          :variable => Variable.t() | View.t(),
          :bound_handle => reference()
        }

  def minimize(variable) do
    bound_handle = init_bound_handle()
    propagator = ObjectivePropagator.new(variable, bound_handle)

    %{
      propagator: propagator,
      variable: variable |> Map.delete(:domain),
      bound_handle: bound_handle,
      target: :minimize
    }
  end

  def maximize(variable) do
    minimize(minus(variable))
    |> Map.put(:target, :maximize)
  end

  def get_bound(%{bound_handle: handle}) do
    get_bound(handle)
  end

  def get_bound(handle) when is_reference(handle) do
    :atomics.get(handle, 1)
  end

  def update_bound(bound_handle, value) do
    case :atomics.exchange(bound_handle, 1, value) do
      prev_value when prev_value >= value ->
        value

      prev_value ->
        # previous value lesser that the new one - set it back
        update_bound(bound_handle, prev_value)
    end
  end

  def tighten(%{variable: variable, bound_handle: handle} = _objective) do
    tighten(variable, handle)
  end

  def tighten(variable, bound_handle) do
    update_bound(bound_handle, Interface.max(variable) - 1)
  end

  def init_bound_handle() do
    ref = :atomics.new(1, signed: true)
    reset_bound_handle(ref)
    ref
  end

  def reset_bound_handle(%{bound_handle: ref} = _objective) do
    reset_bound_handle(ref)
  end

  def reset_bound_handle(ref) do
    :atomics.put(ref, 1, :atomics.info(ref).max)
  end

  def bind_to_store(%{variable: variable} = objective, store) do
    Map.put(objective, :variable, Interface.bind(variable, store))
  end

  def get_objective_value(%{target: target, bound_handle: handle} = _objective) do
    (get_bound(handle) + 1) * ((target == :minimize && 1) || -1)
  end
end
