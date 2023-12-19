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
  def filter([x, y]) do
    filter([x, y, 0])
  end

  def filter([x, y, offset]) do
    filter_impl(x, y, offset)
  end

  def filter_impl(x, y, offset \\ 0) do
    if max(x) <= plus(min(y), offset) do
      ## TODO: it doesn't make sense to filter at all after this happens.
      ## as it will be stable forever.
      ## Consider setting :active flag to exclude propagators from propagation process.
      :passive
    else
      removeAbove(x, plus(max(y), offset))
      removeBelow(y, plus(min(x), -offset))
    end
  end
end
