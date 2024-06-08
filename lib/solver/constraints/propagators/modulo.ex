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
    |> Enum.map(fn var -> set_propagate_on(var, :fixed) end)
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
    filter_impl(args, updated_fixed)
    {:state, %{fixed_flags: updated_fixed}}
  end

  defp update_fixed(fixed_flags, changes) do
    Enum.reduce(changes, fixed_flags, fn {idx, :fixed}, flags_acc ->
      List.replace_at(flags_acc, idx, true)
    end)
  end

  def filter_impl([m, x, y] = _args, @x_y_fixed) do
    fix(m, rem(x, y))
  end

  def filter_impl([m, x, y], @m_x_fixed) do
    m_value = min(m)
    x_value = min(x)

    y_resolved? =
    y
    |> domain()
    |> Domain.to_list()
    |> Enum.reduce_while(false,
    fn y_value, _match_acc ->
      if rem(x_value, y_value) == m_value do
        fix(y, y_value)
        {:halt, true}
      else
        {:cont, false}
      end
    end)
    if y_resolved? do
      :ok
    else
      fail()
    end
  end

  def filter_impl([m, x, y], @m_y_fixed) do
    m_value = min(m)
    y_value = min(y)

    x_resolved? =
    x
    |> domain()
    |> Domain.to_list()
    |> Enum.reduce_while(false,
    fn x_value, _match_acc ->
      if rem(x_value, y_value) == m_value do
        fix(x, x_value)
        {:halt, true}
      else
        {:cont, false}
      end
    end)
    if x_resolved? do
      :ok
    else
      fail()
    end

  end

  def filter_impl(_args, _fixed_flags) do
    :no_action
  end

  defp fail() do
    throw(:fail)
  end

  def initial_state([_m, _x, y] = args) do
    remove(y, 0)
    %{fixed_flags: Enum.map(args, fn arg -> fixed?(arg) end)}
  end
end
