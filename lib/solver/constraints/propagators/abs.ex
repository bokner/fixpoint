defmodule CPSolver.Propagator.Absolute do
  use CPSolver.Propagator

  def new(x, y) do
    new([x, y])
  end

  @impl true
  def variables(args) do
    args
    |> Propagator.default_variables_impl()
    |> Enum.map(fn var -> set_propagate_on(var, :bound_change) end)
  end

  @impl true
  def filter([x, y] = args, state, changes) do
    ((state && map_size(changes) > 0) || initial_reduction(x, y)) && filter_impl(x, y, changes)

    cond do
      failed?(args) ->
        throw(:fail)

      entailed?(args) ->
        :passive

      true ->
        {:state, %{active: true}}
    end
  end

  @impl true
  def failed?([x, y], _state \\ nil) do
    max_y = max(y)

    max(y) < 0 ||
      (
        {abs_min_x, abs_max_x} =
          Enum.min_max_by(domain_values(x), fn val -> abs(val) end)
          |> then(fn {min_val, max_val} -> {abs(min_val), abs(max_val)} end)

        min_y = max(0, min(y))

        abs_min_x > max_y || abs_max_x < min_y
      )
  end

  @impl true
  def entailed?([x, y], _state \\ nil) do
    ## x and y have to be fixed...
    ## y = |x|
    fixed?(x) && fixed?(y) && abs(min(x)) == min(y)
  end

  def filter_impl(x, y, changes) do
    ## x and y have 0 and 1 indices in the list of args
    x_idx = 0
    y_idx = 1

    Enum.each(
      changes,
      fn
        {idx, _change} when idx == x_idx ->
          abs_min_x = abs(min(x))
          abs_max_x = abs(max(x))
          abs_x_lb = min(abs_min_x, abs_max_x)
          abs_x_ub = max(abs_min_x, abs_max_x)

          removeBelow(y, min(min(y), abs_x_lb))
          removeAbove(y, max(max(y), abs_x_ub))

        {idx, _change} when idx == y_idx ->
          y_min = min(y)
          y_max = max(y)

          cond do
            min(x) >= 0 ->
              removeBelow(x, y_min)
              removeAbove(x, y_max)

            max(x) <= 0 ->
              :ok
              removeBelow(x, -y_max)
              removeAbove(x, -y_min)

            true ->
              removeAbove(x, y_max)
              removeBelow(x, -y_max)
          end

        {_idx, _change} ->
          :ignore
      end
    )

    fixed?(x) && fix(y, abs(min(x)))
    fixed?(y) && fix_abs(x, min(y))
  end

  defp initial_reduction(x, y) do
    ## y is non-negative
    removeBelow(y, 0)
    filter_impl(x, y, %{0 => :domain_change, 1 => :domain_change})
  end

  defp fix_abs(x, value) do
    Enum.each(domain_values(x), fn val -> abs(val) != value && remove(x, val) end)
  end
end

defmodule CPSolver.Propagator.AbsoluteNotEqual do
  use CPSolver.Propagator
  alias CPSolver.Propagator.Absolute

  def new(x, y) do
    new([x, y])
  end

  @impl true
  defdelegate variables(args), to: Absolute

  @impl true
  def filter([x, y], _state, _changes) do
    filter_impl(x, y)
  end

  def filter_impl(x, c) when is_integer(c) do
    remove(x, c)
    remove(x, -c)
    :passive
  end

  def filter_impl(x, y) do
    cond do
      fixed?(x) ->
        remove(y, abs(min(x)))
        :passive

      fixed?(y) ->
        y_val = min(y)
        remove(x, y_val)
        remove(x, -y_val)
        :passive

      true ->
        {:state, %{active: true}}
    end
  end

  @impl true
  def failed?(args, state) do
    Absolute.entailed?(args, state)
  end

  @impl true
  def entailed?(args, state) do
    Absolute.failed?(args, state)
  end
end
