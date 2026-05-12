defmodule CPSolver.Search.Utils do
  alias CPSolver.Variable.UnfixedTracker, as: Tracker

  ## Pick all minimal elements according to given minimization function
  def minimals(tracker, variables, min_by_fun) do
    Tracker.iterate(tracker, variables, {[], nil}, fn var, {minimals_acc, current_min} = acc ->
      val = min_by_fun.(var)

      cond do
        is_nil(current_min) || val < current_min -> {[var], val}
        is_nil(val) || val > current_min -> acc
        val == current_min -> {[var | minimals_acc], current_min}
      end
    end, false)
    |> elem(0)
  end

  ## Pick all maximal elements according to given maximization function
  def maximals(tracker, variables, max_by_fun) do
    Tracker.iterate(tracker, variables, {[], -1}, fn var, {maximals_acc, current_max} = acc ->
      val = max_by_fun.(var)

      cond do
        is_nil(val) || val < current_max -> acc
        val > current_max -> {[var], val}
        val == current_max -> {[var | maximals_acc], val}
      end
    end, false)
    |> elem(0)
  end

end
