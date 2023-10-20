defmodule CPSolver.Propagator.NotEqual do
  use CPSolver.Propagator

  @impl true
  def variables(args) do
    args
    |> Propagator.default_variables_impl()
    |> Enum.map(fn var -> set_propagate_on(var, :fixed) end)
  end

  @impl true
  def filter([x, y]) do
    filter([x, y, 0])
  end

  def filter([x, y, offset]) do
    filter(x, y, offset)
  end

  def filter(x, y, offset \\ 0) do
    cond do
      fixed?(x) ->
        remove(y, plus(min(x), -offset))

      fixed?(y) ->
        remove(x, plus(min(y), offset))

      true ->
        :stable
    end
  end
end
