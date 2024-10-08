alias CPSolver.Variable.Interface

alias CPSolver.Variable
alias CPSolver.Variable.View
alias CPSolver.DefaultDomain, as: Domain

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

defimpl Interface, for: Integer do
  def variable(_any), do: nil
  def id(_val), do: nil
  defdelegate map(val, mapper), to: Domain
  def domain(val), do: val
  defdelegate size(val), to: Domain
  defdelegate min(val), to: Domain
  defdelegate max(val), to: Domain
  defdelegate fixed?(val), to: Domain
  defdelegate contains?(val, value), to: Domain
  defdelegate remove(val, remove_val), to: Domain
  defdelegate removeAbove(val, removeAbove), to: Domain
  defdelegate removeBelow(val, removeBelow), to: Domain
  defdelegate fix(value, fixed_value), to: Domain
  def update(val, _field, _value), do: val
end

defimpl Interface, for: Any do
  def variable(_any), do: nil
  def id(non_var), do: not_supported(:id, non_var)
  def map(non_var, _value), do: non_var
  def domain(non_var), do: not_supported(:domain, non_var)
  def size(non_var), do: not_supported(:size, non_var)
  def min(non_var), do: not_supported(:min, non_var)
  def max(non_var), do: not_supported(:max, non_var)
  def fixed?(_), do: true
  def contains?(non_var, _val), do: not_supported(:contains, non_var)
  def remove(non_var, _val), do: not_supported(:remove, non_var)
  def removeAbove(non_var, _val), do: not_supported(:removeAbove, non_var)
  def removeBelow(non_var, _val), do: not_supported(:removeBelow, non_var)
  def fix(non_var, _val), do: not_supported(:fix, non_var)
  def update(non_var, _field, _value), do: not_supported(:update, non_var)

  defp not_supported(non_var, op) do
    throw({:operation_not_supported, op, for: non_var})
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
