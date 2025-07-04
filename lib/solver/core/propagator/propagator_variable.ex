defmodule CPSolver.Propagator.Variable do
  alias CPSolver.Variable
  alias CPSolver.Variable.View
  alias CPSolver.Variable.Interface.ThrowIfFails, as: Interface
  alias CPSolver.Propagator
  import CPSolver.Common

  @propagator_events Propagator.propagator_events()
  @domain_events CPSolver.Common.domain_events()

  @variable_op_results_key :variable_op_results

  defdelegate domain(var), to: Interface
  defdelegate size(var), to: Interface
  defdelegate min(var), to: Interface
  defdelegate max(var), to: Interface
  defdelegate contains?(var, val), to: Interface
  defdelegate id(var), to: Interface
  defdelegate fixed?(var), to: Interface

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

  def set_propagate_on(%View{variable: variable} = view, propagator_event) do
    variable
    |> set_propagate_on(propagator_event)
    |> then(fn var -> Map.put(view, :variable, var) end)
  end

  def set_propagate_on(%Variable{} = var, propagator_event)
      when propagator_event in @propagator_events do
    Map.put(var, :propagate_on, Propagator.to_domain_events(propagator_event))
  end

  defp wrap(op, var, val) do
    apply(Interface, op, [
      var,
      val
    ])
    |> tap(fn res -> save_op(var, res) end)
  end

  defp save_op(_var, :no_change) do
    :ok
  end

  defp save_op(var, domain_change) when domain_change in @domain_events do
    current_changes = ((changes = get_variable_ops()) && changes) || Map.new()

    {_, updated_changes} =
      Map.get_and_update(current_changes, Interface.id(var), fn current_var_change ->
        {current_var_change, stronger_domain_change(current_var_change, domain_change)}
      end)

    Process.put(
      @variable_op_results_key,
      updated_changes
    )
  end

  def get_variable_ops() do
    Process.get(@variable_op_results_key)
  end

  def reset_variable_ops() do
    Process.delete(@variable_op_results_key)
  end

  def plus(:fail, offset) when is_integer(offset) do
    :fail
  end

  def plus(offset, :fail) when is_integer(offset) do
    :fail
  end

  def plus(a, b) when is_integer(a) and is_integer(b) do
    a + b
  end
end
