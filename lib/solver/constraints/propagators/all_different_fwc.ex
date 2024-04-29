defmodule CPSolver.Propagator.AllDifferent.FWC do
  use CPSolver.Propagator

  @moduledoc """
  The forward-checking propagator for AllDifferent constraint.
  """

  @impl true
  def reset(_args, _state) do
    nil
  end

  defp initial_state(args) do
    {variable_map, fixed_ids} =
      Enum.reduce(args, {Map.new(), []}, fn arg, {map_acc, fixed_ids_acc} ->
        {Map.put(map_acc, id(arg), arg),
         (fixed?(arg) && [id(arg) | fixed_ids_acc]) ||
           fixed_ids_acc}
      end)

    %{variable_map: #variable_map
    filter_impl(variable_map, fixed_ids)
  }
  end

  @impl true
  def variables(args) do
    Enum.map(args, fn x_el -> set_propagate_on(x_el, :fixed) end)
  end

  @impl true
  def filter(args) do
    filter(args, nil, %{})
  end

  def filter(args, nil, %{}) do
    filter(args, initial_state(args), %{})
  end

  @impl true
  def filter(_all_vars, %{variable_map: variable_map} = _state, changes) do
    fixed_var_ids = Map.keys(changes)
    {:state, %{variable_map: filter_impl(variable_map, fixed_var_ids)}}
  end

  defp filter_impl(variable_map, []) do
    variable_map
  end

  defp filter_impl(variable_map, [var_id | rest] = _fixed_var_ids) do
    {f_var, variable_map1} = Map.pop(variable_map, var_id)

    if f_var do
      fixed_ids1 = remove_value(variable_map1, rest, min(f_var))
      filter_impl(variable_map, fixed_ids1)
    else
      filter_impl(variable_map, rest)
    end
  end

  ## Remove a value from the domains of variables
  defp remove_value(unfixed_variables, fixed_ids, value) do
    Enum.reduce(
      unfixed_variables,
      fixed_ids,
      fn {_id, var}, fixed_ids_acc ->
        (:fixed == remove(var, value) && [id(var) | fixed_ids_acc]) ||
          fixed_ids_acc
      end
    )
  end
end
