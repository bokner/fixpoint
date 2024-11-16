defmodule CPSolver.Search.VariableSelector.CHB do
  @moduledoc """
  Conflict-history based  variable selector
  (https://www.gecode.org/doc-latest/MPG.pdf, p.8.5.4)
  """
  alias CPSolver.Space
  alias CPSolver.Shared
  alias CPSolver.Variable.Interface
  alias CPSolver.Utils

  @default_q_score 0.05

  def select(variables, data, chb_mode)
      when chb_mode in [:chb_min, :chb_max, :chb_size_min, :chb_size_max] do
    select_impl(variables, data, chb_mode)
    |> Enum.map(fn {var, _chb} -> var end)
  end

  defp select_impl(variables, data, :chb_min) do
    Utils.minimals(
      variable_chbs(variables, Space.get_shared(data)),
      fn {_var, chb} -> chb end
    )
  end

  defp select_impl(variables, data, :chb_max) do
    Utils.maximals(
      variable_chbs(variables, Space.get_shared(data)),
      fn {_var, chb} -> chb end
    )
  end

  defp select_impl(variables, data, :chb_size_min) do
    Utils.minimals(
      variable_chbs(variables, Space.get_shared(data)),
      fn {var, chb} -> chb / Interface.size(var) end
    )
  end

  defp select_impl(variables, data, :chb_size_max) do
    Utils.maximals(
      variable_chbs(variables, Space.get_shared(data)),
      fn {var, chb} ->
        chb / Interface.size(var)
      end
    )
  end

  @doc """
  Initialize CHB data
  """
  def initialize(%{variables: variables} = space_data, q_score \\ @default_q_score) do
    shared = Space.get_shared(space_data)

    Shared.get_auxillary(shared, :chb) ||
      (
        chb_table = Shared.create_shared_ets_table(shared)
        init_variable_chbs(variables, chb_table, q_score)
        Shared.put_auxillary(shared, :chb, %{variable_chbs: chb_table})
      )
  end

  defp init_variable_chbs(variables, chb_table, q_score) do
    Enum.each(variables, fn var -> :ets.insert(chb_table, {Interface.id(var),
      chb_record(q_score, 0)}) end)
  end

  defp chb_record(q_score, last_failure) do
    %{q_score: q_score, last_failure: last_failure}
  end

  @doc """
  Compute chbs of variables in one pass
  """
  def variable_chbs(variables, shared) do
    chb_data = Shared.get_auxillary(shared, :chb)

    if chb_data do
      %{variable_chbs: chb_table} = chb_data

      chbs =
        :ets.select(
          chb_table,
          for(var <- variables, do: {{Interface.id(var), :_}, [], [:"$_"]})
        ) |> Map.new()

      Enum.map(variables, fn var ->
        var_id = Interface.id(var)
        {var, Map.get(chbs, var_id, chb_record(@default_q_score, 0))}
      end)


    else
      Enum.map(variables, fn var -> {var, chb_record(@default_q_score, 0)} end)
    end
  end

  def update_chbs(variables, failure?, shared) do
    %{variable_chbs: chb_table} = Shared.get_auxillary(shared, :chb)
    global_failure_count = failure? && Shared.get_failure_count(shared)
    Enum.each(variables, fn var -> update_variable_chb(var, chb_table, global_failure_count, failure?) end)
  end

  ## Update chb for individual variable in 'shared'
  defp update_variable_chb(%{id: variable_id} = variable, chb_table, failure_count, failure?) do
    cond do
      pruned?(variable) ->
        chb = get_chb(chb_table, variable_id)

        updated_chb = %{chb | q_score: q_score(chb, failure?, failure_count)}
        |> then(fn rec -> failure? && %{rec | last_failure: failure_count} || rec end)

        :ets.insert(chb_table, {variable_id, updated_chb})
      true ->
        :ignore
      end


  end

  defp pruned?(%{initial_size: initial_size} = variable) do
    current_size = try do
      Interface.size(variable)
    catch :fail ->
      0
    end

    initial_size > current_size
  end

  defp q_score(%{q_score: current_qs, last_failure: last_failure} = _current_chb_record, failure?, global_failure_count) do
    alpha = step_size(global_failure_count)
    reward = (failure? && 1 || 0.9) / (global_failure_count - last_failure + 1)
    (1 - alpha) * current_qs + alpha * reward
  end

  def step_size(failure_count) do
    max(0.06, 0.4 - (failure_count * 1.0e-6))
  end

  defp get_chb(table, variable_id)
    when is_reference(table) and is_reference(variable_id) do
      table
      |> :ets.lookup(variable_id)
      |> then(fn rec ->
        !Enum.empty?(rec) && elem(hd(rec), 1) ||
          chb_record(@default_q_score, 0)
      end)
  end
end
