defmodule CPSolver.IntVariable do
  alias CPSolver.IntDomain

  defdelegate dom(var), to: IntDomain
  defdelegate min(var), to: IntDomain
  defdelegate max(var), to: IntDomain
  defdelegate remove(var, val), to: IntDomain
  defdelegate removeAbove(var, val), to: IntDomain
  defdelegate removeBelow(var, val), to: IntDomain

  def make(domain) do
  end

  def fixed?(variable) do
    IntDomain.size(variable) == 1
  end

  def fix(variable, value) do
    IntDomain.removeAllBut(variable, value)
  end
end
