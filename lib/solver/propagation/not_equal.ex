defmodule CPSolver.Propagator.NotEqual do
  @behaviour CPSolver.Propagator

  import CPSolver.IntVariable

  @impl true
  def filter([x, y] = _args) do
    filter(x, y)
  end

  def filter(x, y) do
    cond do
      fixed?(x) ->
        remove(y, min(x))

      fixed?(y) ->
        remove(x, min(y))

      true ->
        :stable
    end
  end
end
