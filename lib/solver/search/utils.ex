defmodule CPSolver.Search.Utils do
  alias CPSolver.Variable.UnfixedTracker, as: Tracker

  ## Pick all minimal elements according to given minimization function
  def minimals(data, min_by_fun) do
    %{initial: initial, reducer_fun: reducer_fun} = minimals_reducer(min_by_fun)
    Tracker.iterate(data, initial, reducer_fun, false)
    |> elem(0)
  end

  ## Pick all maximal elements according to given maximization function
  def maximals(data, max_by_fun) do
    %{initial: initial, reducer_fun: reducer_fun} = maximals_reducer(max_by_fun)
    Tracker.iterate(data, initial, reducer_fun, false)
    |> elem(0)
  end

  def minimals_reducer(min_by_fun) do
    make_reducer(
      {[], nil},
      fn var, {minimals_acc, current_min} = acc ->
      val = min_by_fun.(var)

      cond do
        is_nil(current_min) || val < current_min -> {[var], val}
        is_nil(val) || val > current_min -> acc
        val == current_min -> {[var | minimals_acc], current_min}
      end
    end)
  end

  def maximals_reducer(max_by_fun) do
    make_reducer({
      [], -1},
      fn var, {maximals_acc, current_max} = acc ->
      val = max_by_fun.(var)

      cond do
        is_nil(val) || val < current_max -> acc
        val > current_max -> {[var], val}
        val == current_max -> {[var | maximals_acc], val}
      end
    end
    )
  end

  def make_reducer(initial, reducer_fun) do
    %{initial: initial, reducer_fun: reducer_fun}
  end

end
