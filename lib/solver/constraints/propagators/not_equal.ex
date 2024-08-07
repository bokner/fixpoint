defmodule CPSolver.Propagator.NotEqual do
  use CPSolver.Propagator

  def new(x, y, offset \\ 0) do
    new([x, y, offset])
  end

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
    filter_impl(x, y, offset)
  end

  def filter_impl(x, y, offset \\ 0)

  def filter_impl(x, c, offset) when is_integer(c) do
    remove(x, c + offset)
    :passive
  end

  def filter_impl(x, y, offset) do
    cond do
      fixed?(x) ->
        remove(y, plus(min(x), -offset))
        :passive

      fixed?(y) ->
        remove(x, plus(min(y), offset))
        :passive

      true ->
        :stable
    end
  end
end
