defmodule CPSolver.Propagator.AllDifferent.FWC do
  use CPSolver.Propagator

  @moduledoc """
  The forward-checking propagator for AllDifferent constraint.
  """

  defp initial_state(args) do
    %{unfixed_vars: Enum.to_list(0..(length(args) - 1))}
  end

  @impl true
  def variables(args) do
    Enum.map(args, fn x_el -> set_propagate_on(x_el, :fixed) end)
  end

  @impl true
  def filter(args) do
    filter(args, initial_state(args))
  end

  def filter(args, nil) do
    filter(args, initial_state(args))
  end

  @impl true
  def filter(all_vars, %{unfixed_vars: unfixed_vars} = _state) do
    updated_unfixed_vars = filter_impl(all_vars, unfixed_vars)
    {:state, %{unfixed_vars: updated_unfixed_vars}}
  end

  defp filter_impl(all_vars, unfixed_vars) do
    fwc(all_vars, unfixed_vars, MapSet.new(), [], false)
  end

  ## The list of unfixed variables exhausted, and there were no fixed values.
  ## We stop here
  defp fwc(_all_vars, [], _fixed_values, unfixed_ids, false) do
    unfixed_ids
  end

  ## The list of unfixed variables exhausted, and some new fixed values showed up.
  ## We go through unfixed ids we have collected during previous stage again

  defp fwc(all_vars, [], fixed_values, unfixed_ids, true) do
    fwc(all_vars, unfixed_ids, fixed_values, [], false)
  end

  ## There is still some (previously) unfixed values to check
  defp fwc(all_vars, [idx | rest], fixed_values, ids_to_revisit, changed?) do
    var = Enum.at(all_vars, idx)
    remove_all(var, fixed_values)

    if fixed?(var) do
      ## Variable is fixed or was fixed as a result of removing all fixed values
      fwc(all_vars, rest, MapSet.put(fixed_values, min(var)), ids_to_revisit, true)
    else
      ## Still not fixed, put it to 'revisit' list
      fwc(all_vars, rest, fixed_values, [idx | ids_to_revisit], changed?)
    end
  end

  ## Remove values from the domain of variable
  defp remove_all(variable, values) do
    Enum.map(
      values,
      fn value ->
        remove(variable, value)
      end
    )
    |> Enum.any?(fn res -> res == :fixed end)
  end
end
