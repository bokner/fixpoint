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

  @impl true
  def failed?([x, y], _state) do
    max_y = max(y)
    max(y) < 0 || (
      abs_min_x = abs(min(x))
      abs_max_x = abs(max(x))
      min_x = min(abs_min_x, abs_max_x)
      max_x = max(abs_min_x, abs_max_x)


      min_y = max(0, min(y))

      min_x > max_y || max_x < min_y
    )

  end

  @impl true
  def entailed?([x, y], _state) do
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

defmodule CPSolver.Propagator.AbsoluteNotEqual do
  use CPSolver.Propagator

  def new(x, y) do
    new([x, y])
  end

  @impl true
  defdelegate variables(args), to: CPSolver.Propagator.Absolute

  @impl true
  def filter([x, y]) do
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
        :stable
    end
  end

  @impl true
  def failed?([x, y], _state) do
    fixed?(x) && fixed?(y) && abs(min(x)) == min(y)
  end

  @impl true
  def entailed?([x, y], _state) do
    ## |x| != y holds on the condition below
    max(y) < 0 ||
    (fixed?(x) && fixed?(y) && abs(min(x)) != min(y))
  end

end
