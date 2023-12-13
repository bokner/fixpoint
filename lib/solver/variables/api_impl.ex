alias CPSolver.Variable.Interface

alias CPSolver.Variable
alias CPSolver.Variable.View

defimpl Interface, for: Variable do
  def id(var), do: var.id
  def variable(var), do: var
  def bind(var, store), do: Map.put(var, :store, store)
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
end

defimpl Interface, for: View do
  def id(view), do: view.variable.id

  def variable(view), do: view.variable

  def bind(%{variable: variable} = view, store) do
    variable
    |> Map.put(:store, store)
    |> then(fn bound_var -> Map.put(view, :variable, bound_var) end)
  end

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
end

defimpl Interface, for: Any do
  def variable(_any), do: nil
  def id(var), do: not_supported(:id, var)
  def bind(var, _store), do: not_supported(:bind, var)
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

  defp not_supported(var, op) do
    throw({:operation_not_supported, op, for: var})
  end
end
