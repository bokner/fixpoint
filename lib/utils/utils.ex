defmodule CPSolver.Utils do
  alias CPSolver.Variable.Interface
  alias CPSolver.DefaultDomain, as: Domain

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

  ## Cartesian product of list of lists
  def cartesian([h]) do
    for i <- h do
      [i]
    end
  end

  def cartesian([h | t] = _values, handler \\ nil) do
    for i <- h, j <- cartesian(t) do
      [i | j]
      |> tap(fn res -> handler && handler.(res) end)
    end
  end

  def lazy_cartesian(lists, callback \\ &Function.identity/1) do
    lazy_cartesian(lists, callback, [])
  end

  def lazy_cartesian([head | rest] = _lists, callback, values) do
      Enum.map(head, fn i ->
        more_values = [i | values]
        if !Enum.empty?(rest) do
           lazy_cartesian(rest, callback, more_values)
        else
          callback && callback.(Enum.reverse(more_values))
        end
      end)

  end





  def domain_values(variable_or_view) do
    variable_or_view
    |> Interface.domain()
    |> Domain.to_list()
  end
end
