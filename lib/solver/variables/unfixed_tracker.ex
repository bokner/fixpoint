defmodule CPSolver.Variable.UnfixedTracker do
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

  def iterate(%{unfixed_variables_tracker: tracker, variables: variables} = _data, ordered? \\ true) do
    iterate(tracker, variables, ordered?)
  end

  def iterate(tracker, variables, ordered?) do
    iterate(tracker, variables, [], fn var, acc -> [var | acc] end, ordered?)
    |> Enum.reverse()
  end

  def iterate(%{unfixed_variables_tracker: tracker, variables: variables} = _data, initial, reducer, ordered?) do
    iterate(tracker, variables, initial, reducer, ordered?)
  end

  def iterate(variables, initial, reducer, ordered?) when is_list(variables) do
    Enum.reduce(variables, initial, fn var, acc -> reducer.(var, acc) end)
    |> then(fn vars ->
      ordered? && Enum.sort_by(vars, fn var -> var.index end) || vars
    end)
  end

  def iterate(tracker, variables, initial, reducer, ordered?) when is_function(reducer, 2) do
    if ordered? do
      SparseSet.iterate_ordered(tracker, initial, variable_iterator(tracker, variables, reducer))
    else
      SparseSet.iterate(tracker, initial, variable_iterator(tracker, variables, reducer))
    end
  end

  defp variable_iterator(tracker, variables, reducer) do
    fn idx, acc ->
      var = variables[idx - 1]
      if Interface.fixed?(var) do
        delete(tracker, idx)
        acc
      else
        reducer.(var, acc)
      end
    end
  end

  def empty?(tracker) do
    SparseSet.empty?(tracker)
  end
end
