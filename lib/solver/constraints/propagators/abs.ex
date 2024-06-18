defmodule CPSolver.Propagator.Absolute do
  use CPSolver.Propagator

  alias CPSolver.DefaultDomain, as: Domain

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
  def filter(args) do
    filter(args, nil)
  end

  @impl true
  def filter([x, y], state, changes) do
    (state && filter_impl(x, y, changes)) || initial_reduction(x, y)
    {:state, %{}}
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
    Enum.each(domain(x) |> Domain.to_list(), fn val -> abs(val) != value && remove(x, val) end)
  end
end
