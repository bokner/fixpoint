defmodule CPSolver.Variables.UnfixedTracker do
  alias InPlace.SparseSet
  alias CPSolver.Utils.Vector
  alias CPSolver.Variable.Interface

  def new(variables) when is_list(variables) do
    new(Vector.new(variables))
  end

  def new(variables) do
    variables
    |> Vector.size()
    |> SparseSet.new()
    |> update(variables)
  end

  def update(tracker, variables) do
    each(tracker, fn var_idx ->
      Interface.fixed?(variables[var_idx - 1]) && delete(tracker, var_idx)
    end)
    tracker
  end

  def copy(tracker) do
    SparseSet.copy(tracker)
  end

  def delete(tracker, idx) do
    SparseSet.delete(tracker, idx)
  end

  def serialize(tracker) do
    SparseSet.serialize(tracker)
  end

  def deserialize(tracker) do
    SparseSet.deserialize(tracker)
  end

  def each(tracker, action) do
    SparseSet.each(tracker, action)
  end

  def iterate_ordered(tracker, initial, reducer) do
    SparseSet.iterate_ordered(tracker, initial, reducer)
  end

  def iterate_unfixed(tracker, variables) do
    iterate_unfixed(tracker, variables, [], fn var, acc -> [var | acc] end)
    |> Enum.reverse()
  end

  def iterate_unfixed(tracker, variables, initial, reducer) when is_function(reducer, 2) do
    iterate_ordered(tracker, initial, fn idx, acc ->
      var = variables[idx - 1]
      if Interface.fixed?(var) do
        delete(tracker, idx)
        acc
      else
        reducer.(var, acc)
      end
    end)
  end

  def empty?(tracker) do
    SparseSet.empty?(tracker)
  end
end
