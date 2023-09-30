defmodule CPSolver.Application do
  def start(:normal, []) do
    {:ok, self()}
  end
end
