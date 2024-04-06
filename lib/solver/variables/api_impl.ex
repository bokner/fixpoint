alias CPSolver.Variable.Interface

alias CPSolver.Variable
alias CPSolver.Variable.View

defimpl Interface, for: Variable do
  def id(var), do: var.id
  def variable(var), do: var
  def map(_var, value), do: value
  def domain(var), do: Variable.domain(var)
  def size(var), do: Variable.size(var)
  def min(var), do: Variable.min(var)
  def max(var), do: Variable.max(var)
  def fixed?(var), do: Variable.fixed?(var)
  def contains?(var, val), do: Variable.contains?(var, val)
  def remove(var, val), do: Variable.remove(var, val)
  def removeAbove(var, val), do: Variable.removeAbove(var, val)
  def removeBelow(var, val), do: Variable.removeBelow(var, val)
  def fix(var, val), do: Variable.fix(var, val)
  def update(var, field, value), do: Map.put(var, field, value)
end

defimpl Interface, for: View do
  def id(view), do: view.variable.id

  def variable(view), do: view.variable

  def map(view, value), do: view.mapper.(value)

  def domain(view), do: View.domain(view)
  def size(view), do: View.size(view)
  def min(view), do: View.min(view)
  def max(view), do: View.max(view)
  def fixed?(view), do: View.fixed?(view)
  def contains?(view, val), do: View.contains?(view, val)
  def remove(view, val), do: View.remove(view, val)
  def removeAbove(view, val), do: View.removeAbove(view, val)
  def removeBelow(view, val), do: View.removeBelow(view, val)
  def fix(view, val), do: View.fix(view, val)

  def update(view, field, value) do
    updated_variable = Map.put(variable(view), field, value)
    Map.put(view, :variable, updated_variable)
  end
end

defimpl Interface, for: Any do
  def variable(_any), do: nil
  def id(var), do: not_supported(:id, var)
  def map(var, _value), do: var
  def domain(var), do: not_supported(:domain, var)
  def size(var), do: not_supported(:size, var)
  def min(var), do: not_supported(:min, var)
  def max(var), do: not_supported(:max, var)
  def fixed?(var), do: not_supported(:fixed?, var)
  def contains?(var, _val), do: not_supported(:contains, var)
  def remove(var, _val), do: not_supported(:remove, var)
  def removeAbove(var, _val), do: not_supported(:removeAbove, var)
  def removeBelow(var, _val), do: not_supported(:removeBelow, var)
  def fix(var, _val), do: not_supported(:fix, var)
  def update(var, _field, _value), do: not_supported(:update, var)

  defp not_supported(var, op) do
    throw({:operation_not_supported, op, for: var})
  end
end

defmodule CPSolver.Variable.Interface.ThrowIfFails do
  alias CPSolver.Variable.Interface
  @behaviour Interface

  defdelegate id(var), to: Interface

  defdelegate variable(var), to: Interface
  defdelegate map(var, value), to: Interface

  def domain(var), do: handle_fail(Interface.domain(var), var)
  def size(var), do: handle_fail(Interface.size(var), var)
  def min(var), do: handle_fail(Interface.min(var), var)
  def max(var), do: handle_fail(Interface.max(var), var)
  def fixed?(var), do: handle_fail(Interface.fixed?(var), var)
  def contains?(var, val), do: handle_fail(Interface.contains?(var, val), var)
  def remove(var, val), do: handle_fail(Interface.remove(var, val), var)
  def removeAbove(var, val), do: handle_fail(Interface.removeAbove(var, val), var)
  def removeBelow(var, val), do: handle_fail(Interface.removeBelow(var, val), var)
  def fix(var, val), do: handle_fail(Interface.fix(var, val), var)
  def update(var, field, value), do: handle_fail(Interface.update(var, field, value), var)

  defp handle_fail(:fail, _var), do: throw(:fail)
  defp handle_fail(result, _var), do: result
end
