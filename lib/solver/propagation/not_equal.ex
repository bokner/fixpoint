defmodule CPSolver.Propagator.NotEqual do
  use CPSolver.Propagator

  import CPSolver.Propagator.Variable

  @impl true
  def events() do
    []
  end

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
