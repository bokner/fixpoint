defmodule CPSolver.Propagator.LessOrEqual do
  use CPSolver.Propagator

  def new(x, y, offset \\ 0) do
    new([x, y, offset])
  end

  @impl true
  def variables([x, y | _]) do
    [set_propagate_on(x, :min_change), set_propagate_on(y, :max_change)]
  end

  @impl true
  def filter(args, state \\ %{active?: true})

  def filter([x, y], state) do
    filter([x, y, 0], state)
  end

  @impl true
  def filter([x, y, offset], state) do
    filter_impl(x, y, offset, state || %{active?: true})
  end

  @impl true
  def filter(args, state, _changes) do
    filter(args, state)
  end

  @impl true
  def failed?([x, y, offset], _state) do
    min(x) > plus(max(y), offset)
  end

  @impl true
  def resolved?([x, y, offset], _state) do
    resolved?(x, y, offset)
  end

  defp resolved?(x, y, offset) do
    ## x <= y holds on the condition below
    max(x) <= plus(min(y), offset)
  end

  defp filter_impl(_x, _y, _offset, %{active?: false} = _state) do
    :passive
  end

  defp filter_impl(x, y, offset, %{active?: true} = _state) do
    removeAbove(x, plus(max(y), offset))
    removeBelow(y, plus(min(x), -offset))
    {:state, %{active?: !resolved?(x, y, offset)}}
  end
end
