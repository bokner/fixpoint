defmodule CPSolver.Propagator.Equal do
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
  def filter([x, y], state, changes) do
    filter([x, y, 0], state, changes)
  end

  def filter([x, y, offset], _state, _changes) do
    filter_impl(x, y, offset)
  end

  def filter_impl(x, y, offset \\ 0)

  def filter_impl(x, c, offset) when is_integer(c) do
    fix(x, c + offset)
    :passive
  end

  def filter_impl(x, y, offset) do
    cond do
      fixed?(x) ->
        fix(y, plus(min(x), -offset))

      fixed?(y) ->
        fix(x, plus(min(y), offset))

      true ->
        :stable
    end
  end

  @impl true
  def failed?([x, y, offset], _state) do
    fixed?(x) && fixed?(y) && min(x) != plus(min(y), offset)
  end

  @impl true
  def entailed?([x, y, offset], _state) do
    ## x != y holds on the condition below
    fixed?(x) && fixed?(y) && min(x) == plus(min(y), offset)
  end
end
