defmodule CPSolver.Propagator.AllDifferent.FWC do
  use CPSolver.Propagator

  @moduledoc """
  The forward-checking propagator for AllDifferent constraint.
  """

  @impl true
  def new(args) do
    Propagator.new(__MODULE__, args)
    |> Map.put(:state, initial_state(args))
  end

  defp initial_state(args) do
    %{unfixed_vars: Map.new(args, fn v -> {v.id, v} end)}
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
    filter_impl(all_vars, Map.to_list(unfixed_vars), unfixed_vars)
  end

  defp filter_impl(_all_vars, [], unfixed_vars) do
    unfixed_vars
  end

  defp filter_impl(all_vars, [{var_id, var} | rest], acc) do
    if fixed?(var) do
      remove_variable(var, all_vars)
      filter_impl(all_vars, rest, Map.delete(acc, var_id))
    else
      filter_impl(all_vars, rest, acc)
    end
  end

  ## Remove value of fixed variable from domains of variables
  defp remove_variable(variable, variables) do
    value = min(variable)

    Enum.each(
      variables,
      fn
        var when var.id == variable.id ->
          :ok

        var ->
          case remove(var, value) do
            :fixed -> remove_variable(var, variables)
            _ -> :ok
          end
      end
    )
  end
end
