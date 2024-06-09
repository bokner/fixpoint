defmodule CPSolver.Propagator.Modulo do
  use CPSolver.Propagator

  @x_y_fixed [false, true, true]
  @m_x_fixed [true, true, false]
  @m_y_fixed [true, false, true]

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
    updated_fixed = update_fixed(fixed_flags, changes)
    updated_fixed2 = case filter_impl(args, updated_fixed) do
      idx when is_integer(idx) -> List.replace_at(updated_fixed, idx, true)
      _other -> updated_fixed
    end
    {:state, %{fixed_flags: updated_fixed2}}
  end

  defp update_fixed(fixed_flags, changes) do
    Enum.reduce(changes, fixed_flags,
    fn {idx, :fixed}, flags_acc ->
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

    ## Modulo and dividend must have the same sign
    if m_value * x_value < 0, do: fail()

      domain(y)
      |> Domain.to_list()
      |> Enum.each(
        fn y_value ->
          (rem(x_value, y_value) != m_value) &&
             remove(y, y_value)
        end
      )
      fixed?(y) && 2 || nil
  end

  def filter_impl([m, x, y], @m_y_fixed) do
    m_value = min(m)
    y_value = min(y)

      domain(x)
      |> Domain.to_list()
      |> Enum.each(
        fn x_value ->
          (rem(x_value, y_value) != m_value) &&
            remove(x, x_value)
        end
      )
      fixed?(x) && 1 || nil
  end

  def filter_impl([m, x, _y], _fixed_flags) do
    if max(m) * min(x) < 0, do: fail()
  end

  defp fail() do
    throw(:fail)
  end

  def initial_state([_m, _x, y] = args) do
    remove(y, 0)
    %{fixed_flags: Enum.map(args, fn arg -> fixed?(arg) end)}
  end
end
