defmodule CPSolver.Propagator.Variable do
  alias CPSolver.Variable
  alias CPSolver.ConstraintStore

  @variable_op_results_key :variable_op_results
  @store_impl_key :store_impl
  defdelegate domain(var), to: Variable
  defdelegate size(var), to: Variable
  defdelegate min(var), to: Variable
  defdelegate max(var), to: Variable
  defdelegate fixed?(var), to: Variable
  defdelegate contains?(var, val), to: Variable

  def remove(var, val) do
    wrap(:remove, var, val)
  end

  def removeAbove(var, val) do
    wrap(:removeAbove, var, val)
  end

  def removeBelow(var, val) do
    wrap(:removeBelow, var, val)
  end

  def fix(var, val) do
    wrap(:fix, var, val)
  end

  defp wrap(op, var, val) do
    save_in_dict(var, apply(Variable, op, [var, val]))
  end

  defp save_in_dict(var, result) do
    result
    |> tap(fn
      :fail ->
        Process.put(@variable_op_results_key, {:fail, var.id})

      _ ->
        current = get_variable_ops()
        Process.put(@variable_op_results_key, Map.put(current, var.id, result))
    end)
  end

  def get_variable_ops() do
    Process.get(@variable_op_results_key, Map.new())
  end

  def set_store_impl(store_impl) do
    Process.put(@store_impl_key, store_impl)
  end

  def get_store_impl() do
    Process.get(@store_impl_key) || ConstraintStore.default_store()
  end

  def reset_variable_ops() do
    Process.delete(@variable_op_results_key)
  end

  def plus(:fail, _) do
    :fail
  end

  def plus(_, :fail) do
    :fail
  end

  def plus(a, b) do
    a + b
  end
end