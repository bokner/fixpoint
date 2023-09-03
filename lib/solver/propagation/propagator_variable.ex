defmodule CPSolver.Propagator.Variable do
  alias CPSolver.Common
  alias CPSolver.Variable

  @domain_changes Common.domain_changes()

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
    case apply(Variable, op, [var, val]) do
      res when res in @domain_changes ->
        if Process.get(:stable_flag) do
          Process.put(:stable_flag, false)
        end

        res

      :fail ->
        :fail

      _res ->
        :no_change
    end
  end
end
