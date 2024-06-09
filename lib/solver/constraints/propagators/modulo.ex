defmodule CPSolver.Propagator.Modulo do
  use CPSolver.Propagator

  @x_y_fixed [false, true, true]
  @m_x_fixed [true, true, false]
  @m_y_fixed [true, false, true]
  @all_fixed [true, true, true]

  def new(m, x, y) do
    new([m, x, y])
  end

  @impl true
  def variables(args) do
    args
    |> Propagator.default_variables_impl()
    |> Enum.map(fn var -> set_propagate_on(var, :bound_change) end)
  end

  @impl true
  def filter(args) do
    filter(args, initial_state(args))
  end

  @impl true
  def filter(args, nil, changes) do
    filter(args, initial_state(args), changes)
  end

  def filter(args, %{fixed_flags: fixed_flags}, changes) do
    updated_fixed = update_fixed(args, fixed_flags, changes)

    if filter_impl(args, updated_fixed) do
      :passive
    else
      {:state, %{fixed_flags: updated_fixed}}
    end
  end

  ## This (no changes) will happen when the propagator doesn't receive changes
  ## (either because it was first to run or there were no changes)
  defp update_fixed(args, fixed_flags, changes) when map_size(changes) == 0 do
    for idx <- 0..2 do
      Enum.at(fixed_flags, idx) || fixed?(Enum.at(args, idx))
    end
  end

  defp update_fixed(_args, fixed_flags, changes) do
    Enum.reduce(changes, fixed_flags, fn
      {idx, :fixed}, flags_acc ->
        List.replace_at(flags_acc, idx, true)

      {_idx, _bound_change}, flags_acc ->
        flags_acc
    end)
  end

  def filter_impl([m, x, y] = _args, @x_y_fixed) do
    fix(m, rem(min(x), min(y)))
  end

  def filter_impl([m, x, y], @m_x_fixed) do
    m_value = min(m)
    x_value = min(x)

    domain(y)
    |> Domain.to_list()
    |> Enum.each(fn y_value ->
      rem(x_value, y_value) != m_value &&
        remove(y, y_value)
    end)

    fixed?(y)
  end

  def filter_impl([m, x, y], @m_y_fixed) do
    m_value = min(m)
    y_value = min(y)

    domain(x)
    |> Domain.to_list()
    |> Enum.each(fn x_value ->
      rem(x_value, y_value) != m_value &&
        remove(x, x_value)
    end)

    fixed?(x)
  end

  def filter_impl(_args, @all_fixed) do
    true
  end

  def filter_impl(_args, [true | _x_y_flags]) do
    false
  end

  def filter_impl([m, x, _y] = args, [false | x_y_flags]) do
    max_x = max(x)
    min_x = min(x)
    m_lower_bound = min(min_x, 0)
    m_upper_bound = max(max_x, 0)
    removeAbove(m, m_upper_bound)
    removeBelow(m, m_lower_bound)
    fixed?(m) && filter_impl(args, [true | x_y_flags])
  end

  def initial_state([_m, _x, y] = args) do
    remove(y, 0)
    %{fixed_flags: Enum.map(args, fn arg -> fixed?(arg) end)}
  end
end
