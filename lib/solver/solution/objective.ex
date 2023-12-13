defmodule CPSolver.Solution.Objective do
  alias CPSolver.Variable
  alias CPSolver.Variable.Interface
  alias CPSolver.Variable.View
  import CPSolver.Variable.View.Factory

  @spec minimize(Variable.t() | View.t()) :: %{
          :variable => Variable.t() | View.t(),
          :bound_handle => reference()
        }
  def minimize(variable) do
    bound_handle = init_bound_handle()

    %{variable: variable, bound_handle: bound_handle}
    |> tap(fn _ -> update_bound(bound_handle, Interface.max(variable)) end)
  end

  @spec maximize(Variable.t() | View.t()) :: %{
          :variable => View.t(),
          :bound_handle => reference()
        }
  def maximize(variable) do
    minimize(minus(variable))
  end

  def get_bound(%{bound_handle: handle}) do
    get_bound(handle)
  end

  def get_bound(handle) when is_reference(handle) do
    :atomics.get(handle, 1)
  end

  def update_bound(bound_handle, value) do
    current = get_bound(bound_handle)

    if current > value do
      case :atomics.compare_exchange(bound_handle, 1, current, value) do
        :ok -> value
        changed_bound when changed_bound > value -> update_bound(bound_handle, value)
        lesser_or_equal_bound -> lesser_or_equal_bound
      end
    else
      current
    end
  end

  def tighten() do
  end

  def init_bound_handle() do
    ref = :atomics.new(1, signed: true)
    max_val = :atomics.info(ref).max
    :atomics.put(ref, 1, max_val)
    ref
  end
end
