defmodule CPSolver.Utils.MutableArray do
  ## This one is being used by AllDifferent.BC
  ## The issue is that every time the filtering happens, it needs to update some already sorted lists.
  ## based on incoming domain changes.
  ## Doing sorting from scratch is expensive, so the goal is to update and keep the array sorted
  ## based only on the in coming change.
  ##
  ## `values` is a list of (unsorted) values - this would be a list of variables' lower or upper bounds
  ## `sorted_index is a list, s.t. sorted_index[i] holds the position of values[i] in the sorted list.
  ## The upshot is that `values` and `sorted_index` represent a sorted list of `values.
  ## `updated_index` - the index of the changed value in `values`
  ## `updated_value` - the new value for values[updated_index]
  ##
  ## For instance:
  ## values = [2, 8, 3, 5, 2]
  ## The sorted index would be:
  ## sorted_index = [0, 4, 2, 3, 1]
  ##
  ## updated_index = 1, updated_value = 2
  ## means that values[1] (that had value 8) had been updated to 2
  ##
  ## Note: `value` and `sorted_index` are represented by :atomics
  ## in order to facilitate fast access and updates in place
  ##
  def update_sorted(values, sort_index, {updated_index, new_value} = change)
    when is_reference(values) and is_reference(sort_index) and is_integer(updated_index) and is_integer(new_value) do
      updated_pos = array_get(sort_index, updated_index)
      update_sorted_impl(updated_pos, values, sort_index, new_value)
      array_update(values, updated_index, new_value)
  end

  defp update_sorted_impl(0, _values, _sort_index, _new_value) do
    :ok
  end

  defp update_sorted_impl(pos, values, sort_index, new_value) do
    if array_get(values, pos - 1) > new_value do
      swap(sort_index, pos, pos - 1)
      update_sorted_impl(pos - 1, values, sort_index, new_value)
    else
      :ok
    end
  end

  defp swap(array, index1, index2) do
    val1 = array_get(array, index1)
    val2 = array_get(array, index2)
    array_update(array, index1, val2)
    array_update(array, index2, val1)
  end




  def make_array(arity) when is_integer(arity) do
    :atomics.new(arity, signed: true)
  end

  def make_array(list) when is_list(list) do
    ref = make_array(length(list))

    Enum.reduce(list, 1, fn el, idx ->
      :atomics.put(ref, idx, el)
      idx + 1
    end)

    ref
  end

  def array_update(ref, zb_index, value)
       when is_reference(ref) and zb_index >= 0 and is_integer(value) do
    :atomics.put(ref, zb_index + 1, value)
  end

  def array_add(ref, zb_index, value)
       when is_reference(ref) and zb_index >= 0 and is_integer(value) do
    :atomics.add(ref, zb_index + 1, value)
  end

  def array_get(ref, zb_index) when is_reference(ref) and zb_index >= 0 do
    :atomics.get(ref, zb_index + 1)
  end

  def to_array(ref, fun \\ fn _i, val -> val end) do
    for i <- 1..:atomics.info(ref).size do
      fun.(i, :atomics.get(ref, i))
    end
  end

end
