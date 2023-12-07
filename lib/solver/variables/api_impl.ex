alias CPSolver.Variable.Interface

alias CPSolver.Variable
alias CPSolver.Variable.View

defimpl Interface, for: Variable do
  def id(var), do: var.id
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
