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
    filter_impl(all_vars, unfixed_vars, MapSet.new(unfixed_vars))
  end

  defp filter_impl(_all_vars, [], unfixed_vars) do
    MapSet.to_list(unfixed_vars)
  end

  defp filter_impl(all_vars, [idx | rest], acc) do
    var = Enum.at(all_vars, idx)

    if fixed?(var) do
      remove_variable(var, all_vars)
      filter_impl(all_vars, rest, MapSet.delete(acc, idx))
    else
      filter_impl(all_vars, rest, acc)
    end
  end

  ## Remove value of fixed variable from domains of variables
  defp remove_variable(variable, variables) do
    value = min(variable)

    Enum.each(
      variables,
      fn var ->
        if id(var) == id(variable) do
          :ok
        else
          case remove(var, value) do
            :fixed -> remove_variable(var, variables)
            _ -> :ok
          end
        end
      end
    )
  end
end
