defmodule CPSolver.Search.Utils do
  alias CPSolver.Variable.UnfixedTracker, as: Tracker

  def process(data, %{initial: initial, reducer_fun: reducer_fun, postprocess_fun: postprocess_fun} = _processor, ordered? \\ false) do
    Tracker.iterate(data, initial, reducer_fun, ordered?)
    |> postprocess_fun.()
  end
  ## Pick all minimal elements according to given minimization function
  def minimals(data, min_by_fun, postprocess_fun \\ fn {x, _} -> x end) do
    process(data, minimals_processor(min_by_fun, postprocess_fun), false)
  end

  ## Pick all maximal elements according to given maximization function
  def maximals(data, max_by_fun, postprocess_fun \\ fn {x, _} -> x end) do
    process(data, maximals_processor(max_by_fun, postprocess_fun), false)
  end

  def minimals_processor(min_by_fun, postprocess_fun) do
    processor(
      {[], nil},
      fn var, {minimals_acc, current_min} = acc ->
        val = min_by_fun.(var)

        cond do
          is_nil(current_min) || val < current_min -> {[var], val}
          is_nil(val) || val > current_min -> acc
          val == current_min -> {[var | minimals_acc], current_min}
        end
      end,
      postprocess_fun
    )
  end

  def maximals_processor(max_by_fun, postprocess_fun) do
    processor(
      {
        [],
        -1
      },
      fn var, {maximals_acc, current_max} = acc ->
        val = max_by_fun.(var)

        cond do
          is_nil(val) || val < current_max -> acc
          val > current_max -> {[var], val}
          val == current_max -> {[var | maximals_acc], val}
        end
      end,
      postprocess_fun
    )
  end

  def processor(initial, reducer_fun, postprocess_fun \\ fn x -> x end) do
    %{initial: initial, reducer_fun: reducer_fun, postprocess_fun: postprocess_fun}
  end
end
