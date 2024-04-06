defmodule CPSolver.Objective do
  alias CPSolver.Objective.Propagator, as: ObjectivePropagator
  alias CPSolver.Variable.Interface
  import CPSolver.Variable.View.Factory
  import CPSolver.Utils

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
      variable: variable,
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
    (on_primary_node?(handle) && get_bound_impl(handle)) || remote_call(handle, :get_bound_impl)
  end

  def get_bound_impl(handle) when is_reference(handle) do
    :atomics.get(handle, 1)
  end

  def update_bound(handle, value) when is_reference(handle) do
    (on_primary_node?(handle) && update_bound_impl(handle, value)) ||
      remote_call(handle, :update_bound_impl, [value])
  end

  def update_bound_impl(bound_handle, value) do
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
    reset_bound(ref)
    ref
  end

  def reset_bound(%{bound_handle: ref} = _objective) do
    reset_bound(ref)
  end

  def reset_bound(handle) when is_reference(handle) do
    (on_primary_node?(handle) && reset_bound_impl(handle)) ||
      remote_call(handle, :reset_bound_impl)
  end

  def reset_bound_impl(ref) when is_reference(ref) do
    :atomics.put(ref, 1, :atomics.info(ref).max)
  end

  def get_objective_value(%{target: target, bound_handle: handle} = _objective) do
    (get_bound(handle) + 1) * ((target == :minimize && 1) || -1)
  end

  defp remote_call(ref, fun_name, args \\ []) when is_reference(ref) and is_atom(fun_name) do
    :erpc.call(node(ref), __MODULE__, fun_name, [ref | args])
  end
end
