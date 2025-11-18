defmodule CPSolver.Utils do
  alias CPSolver.Variable.Interface
  alias CPSolver.IntVariable, as: Variable
  alias CPSolver.DefaultDomain, as: Domain
  alias Iter.Iterable

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

  def lazy_cartesian([head], callback, acc) do
    Enum.each(head, fn v -> callback.([v | acc]) end)
  end

  def lazy_cartesian([head | rest] = _lists, callback, acc) do
    Enum.each(head, fn i ->
      lazy_cartesian(rest, callback, [i | acc])
    end)
  end

  def domain_values(variable_or_view, access \\ :interface) do
    cond do
      access == :interface -> Interface.domain(variable_or_view)
      access == :variable -> Variable.domain(variable_or_view)
      true -> throw{:error, :unknown_access_type}
    end
    |> Domain.to_list()
  end

  ## Pick all minimal elements according to given minimizing function
  def minimals(enumerable, min_by_fun) do
    List.foldr(enumerable, {[], nil}, fn el, {minimals_acc, current_min} = acc ->
      val = min_by_fun.(el)

      cond do
        is_nil(current_min) || val < current_min -> {[el], val}
        is_nil(val) || val > current_min -> acc
        val == current_min -> {[el | minimals_acc], current_min}
      end
    end)
    |> elem(0)
  end

  ## Pick all maximal elements according to given maximizing function
  def maximals(enumerable, max_by_fun) do
    List.foldr(enumerable, {[], -1}, fn el, {maximals_acc, current_max} = acc ->
      val = max_by_fun.(el)

      cond do
        is_nil(val) || val < current_max -> acc
        val > current_max -> {[el], val}
        val == current_max -> {[el | maximals_acc], val}
      end
    end)
    |> elem(0)
  end

  def iterate(iterator, acc, fun) do
    case Iterable.next(iterator) do
      :done -> acc
      {:ok, neighbor, rest} ->
        case fun.(neighbor, acc) do
          {:halt, acc_new} ->
            acc_new
          {:cont, acc_new} ->
            iterate(rest, acc_new, fun)
        end
    end
  end
end
