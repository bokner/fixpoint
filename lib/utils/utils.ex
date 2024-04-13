defmodule CPSolver.Utils do
  def on_primary_node?(arg) when is_reference(arg) or is_pid(arg) or is_port(arg) do
    Node.self() == node(arg)
  end

  def array2d_min_max(arr) do
    n_rows = length(arr)
    n_cols = length(hd(arr))
    first = Enum.at(arr, 0) |> Enum.at(0)

    for i <- 0..(n_rows - 1), j <- 0..(n_cols - 1), reduce: {first, first} do
      {acc_min, acc_max} ->
        val = Enum.at(arr, i) |> Enum.at(j)

        cond do
          val < acc_min -> {val, acc_max}
          val > acc_max -> {acc_min, val}
          true -> {acc_min, acc_max}
        end
    end
  end
end
