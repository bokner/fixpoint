alias CPSolver.Variable.Interface

alias CPSolver.Variable
alias CPSolver.Variable.View

defimpl Interface, for: Variable do
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
  def domain(var), do: View.domain(var)
  def size(var), do: View.size(var)
  def min(var), do: View.min(var)
  def max(var), do: View.max(var)
  def fixed?(var), do: View.fixed?(var)
  def contains?(var, val), do: View.contains?(var, val)
  def remove(var, val), do: View.remove(var, val)
  def removeAbove(var, val), do: View.removeAbove(var, val)
  def removeBelow(var, val), do: View.removeBelow(var, val)
  def fix(var, val), do: View.fix(var, val)
end
