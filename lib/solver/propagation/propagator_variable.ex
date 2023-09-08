defmodule CPSolver.Propagator.Variable do
  alias CPSolver.Variable

  @variable_op_results_key :variable_op_results

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

  def reset_variable_ops() do
    Process.delete(@variable_op_results_key)
  end
end