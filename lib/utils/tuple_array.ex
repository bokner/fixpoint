defmodule CPSolver.Utils.TupleArray do
  def new(values) when is_list(values) do
    Enum.reduce(values, {}, fn
      val, acc when is_list(val) ->
        Tuple.insert_at(acc, tuple_size(acc), new(val))

      val, acc ->
        Tuple.insert_at(acc, tuple_size(acc), val)
    end)
  end

  def at(tuple_array, idx) when is_integer(idx) do
    (idx >= 0 && tuple_size(tuple_array) - 1 >= idx &&
       elem(tuple_array, idx)) ||
      nil
  end

  def at(tuple_array, []) do
    tuple_array
  end

  def at(tuple_array, [idx | rest]) do
    at(tuple_array, idx)
    |> then(fn sub_arr -> (sub_arr && at(sub_arr, rest)) || nil end)
  end

  def map(tuple_array, mapper) when is_function(mapper) do
    Enum.reduce(0..(tuple_size(tuple_array) - 1), {}, fn idx, acc ->
      Tuple.insert_at(acc, tuple_size(acc), mapper.(elem(tuple_array, idx)))
    end)
  end

  def reduce(tuple_array, initial_value, reducer) when is_function(reducer) do
    Enum.reduce(0..(tuple_size(tuple_array) - 1), initial_value, fn idx, acc ->
      reducer.(elem(tuple_array, idx), acc)
    end)
  end
end
