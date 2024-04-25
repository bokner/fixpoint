defmodule CPSolver.Utils.TupleArray do
  def new(values) when is_list(values) do
    Enum.reduce(values, {}, fn
      val, acc when is_list(val) ->
        Tuple.append(acc, new(val))

      val, acc ->
        Tuple.append(acc, val)
    end)
  end

  def get(tuple_array, idx) when is_integer(idx) do
    (idx >= 0 && tuple_size(tuple_array) - 1 >= idx &&
       elem(tuple_array, idx)) ||
      nil
  end

  def get(tuple_array, []) do
    tuple_array
  end

  def get(tuple_array, [idx | rest]) do
    get(tuple_array, idx)
    |> then(fn sub_arr -> (sub_arr && get(sub_arr, rest)) || nil end)
  end
end
