defmodule CPSolver.Propagator.Variable do
  alias CPSolver.Variable
  alias CPSolver.Propagator

  @propagator_events Propagator.propagator_events()
  @domain_events CPSolver.Common.domain_events()

  @variable_op_results_key :variable_op_results

  defdelegate domain(var), to: Variable
  defdelegate size(var), to: Variable
  defdelegate min(var), to: Variable
  defdelegate max(var), to: Variable
  defdelegate contains?(var, val), to: Variable

  def fixed?(var) do
    Map.get(var, :fixed?) || Variable.fixed?(var)
  end

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

  def set_propagate_on(var, nil) do
    set_propagate_on(var, :fixed)
  end

  def set_propagate_on(%Variable{} = var, propagator_event)
      when propagator_event in @propagator_events do
    Map.put(var, :propagate_on, Propagator.to_domain_events(propagator_event))
  end

  defp wrap(op, var, val) do
    case apply(Variable, op, [
           var,
           val
         ]) do
      :fail ->
        throw({:fail, var.id})

      res ->
        save_op(var, res)
        res
    end
  end

  defp save_op(_var, :no_change) do
    :ok
  end

  defp save_op(var, domain_change) when domain_change in @domain_events do
    current_changes = ((changes = get_variable_ops()) && changes) || Map.new()
    Process.put(@variable_op_results_key, Map.put(current_changes, var.id, domain_change))
  end

  def get_variable_ops() do
    Process.get(@variable_op_results_key)
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