defmodule CPSolver.Utils.MutableOrder do
  alias CPSolver.Utils.MutableArray
  import CPSolver.Utils.MutableArray

  @moduledoc """
  'mutable order' structure.

  Currently being used by AllDifferent.BC
  The motivation:
  every time the filtering happens, it needs to update some already sorted lists of lower and/or upper bounds.

  Doing sorting from scratch is expensive, so the goal is to update and keep the array sorted
  based only on the incoming changes.

  `values` is a list of (unsorted) values - this would be a list of variables' lower or upper bounds
  `sorted_index is a list, s.t. sorted_index[i] holds the position of values[i] in the sorted list.
  The upshot is that `values` and `sorted_index` represent a sorted list of `values.
  `updated_index` - the index of the changed value in `values`
  `updated_value` - the new value for values[updated_index]

  For instance:
  values = [2, 8, 3, 5, 2]
  The sorted index would be:
  sorted_index = [0, 4, 2, 3, 1]

  updated_index = 1, updated_value = 2
  means that values[1] (that had value 8) had been updated to 2

  Note: `value` and `sorted_index` are represented by :atomics
  in order to facilitate fast access and updates in place

  """

  @doc """
  Creates an order structure from (unsorted) array
  """
  def new(values) when is_list(values) do
    n = length(values)

    values_ref = MutableArray.new(values)
    sort_index_ref = MutableArray.new(n)
    value_positions_ref = MutableArray.new(n)

    values
    |> Enum.with_index()
    |> Enum.sort()
    |> Enum.with_index()
    |> Enum.sort_by(fn {{_val, sorted_idx}, _pos} -> sorted_idx end)
    |> Enum.reduce(0, fn {{_val, sorted_idx}, pos}, pos_acc ->
      array_update(value_positions_ref, pos_acc, pos)
      array_update(sort_index_ref, pos, sorted_idx)
      pos_acc + 1
    end)

    %{values: values_ref, sort_index: sort_index_ref, positions: value_positions_ref}
  end

  @doc "Get value by index in sorted array"
  def get(order_rec, index) do
    array_get(order_rec.values, array_get(order_rec.sort_index, index))
  end

  def update(
        %{values: values_ref, positions: positions_ref, sort_index: sort_index_ref} = _order_rec,
        change
      ) do
    update(values_ref, positions_ref, sort_index_ref, change)
  end

  def update(values, positions, sort_index, {change_index, new_value} = _change)
      when is_reference(values) and is_reference(sort_index) and is_integer(change_index) and
             is_integer(new_value) do
    case array_get(values, change_index) do
      current_value when current_value == new_value ->
        :ok

      current_value ->
        change_pos = array_get(positions, change_index)

        update_order_impl(
          change_pos,
          values,
          positions,
          sort_index,
          new_value,
          (current_value > new_value && 0) || array_size(values) - 1
        )

        array_update(values, change_index, new_value)
    end
  end

  defp update_order_impl(current_pos, _values, _positions, _sort_index, _new_value, last_pos)
       when current_pos == last_pos do
    :ok
  end

  defp update_order_impl(pos, values, positions, sort_index, new_value, 0) do
    next_pos = pos - 1
    ## The sort index is sorted by values indices refer to
    ## To find an actual value in referred lists (values, positions), we need to get an index value
    next_pos_pointer = array_get(sort_index, next_pos)
    if array_get(values, next_pos_pointer) > new_value do
      swap(sort_index, pos, next_pos)
      swap(positions, next_pos_pointer, array_get(sort_index, next_pos))
      update_order_impl(next_pos, values, positions, sort_index, new_value, 0)
    else
      :ok
    end
  end

  defp update_order_impl(pos, values, positions, sort_index, new_value, last_index) do
    next_pos = pos + 1
    ## The sort index is sorted by values indices refer to
    ## To find an actual value in referred lists (values, positions), we need to get an index value
    next_pos_pointer = array_get(sort_index, next_pos)
    if array_get(values, next_pos_pointer) < new_value do
      swap(sort_index, pos, next_pos)
      swap(positions, next_pos_pointer, array_get(sort_index, next_pos))
      update_order_impl(next_pos, values, positions, sort_index, new_value, last_index)
    else
      :ok
    end
  end

  def to_sorted(%{values: values, sort_index: sort_index} = _order_rec, order \\ :asc) do
    to_sorted(values, sort_index, order)
  end

  def to_sorted(values, sort_index, order) do
    Enum.reduce(1..array_size(sort_index), [], fn idx, acc ->
      sort_pos = array_get(sort_index, idx - 1)
      [{sort_pos, array_get(values, sort_pos)} | acc]
    end)
    |> then(fn desc -> (order == :asc && Enum.reverse(desc)) || desc end)
  end

  def valid?(order_rec, order \\ :asc) do
    ordered_values = to_sorted(order_rec, order) |> Enum.unzip() |> elem(1)
    Enum.sort(ordered_values, order) == ordered_values
  end
end
