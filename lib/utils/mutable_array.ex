defmodule CPSolver.Utils.MutableArray do
  def swap(array, index1, index2) do
    val1 = array_get(array, index1)
    val2 = array_get(array, index2)
    array_update(array, index1, val2)
    array_update(array, index2, val1)
  end

  def new(arity) when is_integer(arity) do
    :atomics.new(arity, signed: true)
  end

  def new(list) when is_list(list) do
    ref = new(length(list))

    Enum.reduce(list, 1, fn el, idx ->
      :atomics.put(ref, idx, el)
      idx + 1
    end)

    ref
  end

  def array_size(ref) do
    :atomics.info(ref).size
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
