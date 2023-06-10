defmodule CPSolver.IntDomain do
  @behaviour CPSolver.Domain

  @impl
  def dom(variable) do
    []
  end

  def contains?(variable, value) do
    false
  end

  def size(variable) do
    0
  end

  def min(variable) do
    0
  end

  def max(variable) do
    0
  end

  def remove(variable, value) do
  end

  def removeAbove(variable, value) do
  end

  def removeBelow(variable, value) do
  end

  def removeAllBut(variable, value) do
  end
end
