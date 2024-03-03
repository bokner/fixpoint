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

  def filter_impl(_x, _y, _offset, %{active?: false} = _state) do
    :passive
  end

  def filter_impl(x, y, offset, %{active?: true} = _state) do
    removeAbove(x, plus(max(y), offset))
    removeBelow(y, plus(min(x), -offset))

    ## It doesn't make sense to filter at all after this happens.
    ## as it will be stable forever.
    {:state, %{active?: max(x) > plus(min(y), offset)}}
  end
end
