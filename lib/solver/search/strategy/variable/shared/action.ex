defmodule CPSolver.Search.VariableSelector.Action do
  @moduledoc """
  Action (activity-based) variable selector
  (https://www.gecode.org/doc-latest/MPG.pdf, p.8.5.3)
  """
  use CPSolver.Search.VariableSelector
  alias CPSolver.Space
  alias CPSolver.Shared
  alias CPSolver.Variable.Interface
  alias CPSolver.Utils

  @default_action_value 1

  @impl true
  def select(data, opts) do
    data
    |> variable_actions(Space.get_shared(data) |> Shared.get_auxillary(:action))
    |> select_impl(opts[:mode])
    |> Enum.map(fn {var, _afc} -> var end)
  end

  defp select_impl(actions, :action_min) do
    Utils.minimals(actions,
      fn {_var, action} -> action end
    )
  end

  defp select_impl(actions, :action_max) do
    Utils.maximals(actions,
      fn {_var, action} -> action end
    )
  end

  defp select_impl(actions, :action_size_min) do
    Utils.minimals(actions,
      fn {var, action} -> action / Interface.size(var) end
    )
  end

  defp select_impl(actions, :action_size_max) do
    Utils.maximals(actions,
      fn {var, action} -> action / Interface.size(var) end
    )
  end

  @doc """
  Initialize Action data
  """
  @impl true
  def initialize(%{variables: variables} = space_data, opts) do
    shared = Space.get_shared(space_data)

    Shared.get_auxillary(shared, :action) ||
      (
        action_table = Shared.create_shared_ets_table(shared)
        init_variable_actions(variables, action_table)

        Shared.put_auxillary(shared, :action, %{
          variable_actions: action_table,
          decay: opts[:decay]
        })

        Shared.add_handler(shared, :on_space_finalized, fn solver,
                                                           %{variables: variables} = _space_data,
                                                           _reason ->
          Shared.complete?(solver) ||
            update_actions(variables, solver)
        end)
      )
  end

  defp init_variable_actions(variables, action_table) do
    Enum.each(variables, fn var ->
      :ets.insert(action_table, {Interface.id(var), @default_action_value})
    end)
  end

  @doc """
  Compute actions of variables in one pass
  """
  def variable_actions(space_data, %{variable_actions: action_table} = _action_data) do
      actions =
        :ets.select(
          action_table,
          Tracker.iterate(space_data, [], fn var, acc ->
            [{{Interface.id(var), :_}, [], [:"$_"]} | acc] end, false)
        )
        |> Map.new()

      Tracker.iterate(space_data, [], fn var, acc ->
        var_id = Interface.id(var)
        [{var, Map.get(actions, var_id, @default_action_value)} | acc]
      end, false)
  end

  def variable_actions(space_data, _action_data) do
    Tracker.iterate(space_data, [], fn var, acc -> [{var, @default_action_value} | acc ] end, false)
  end

  def update_actions(variables, shared) do
    case Shared.get_auxillary(shared, :action) do
      nil ->
        :ok

      %{variable_actions: action_table, decay: decay} ->
        Enum.each(variables, fn var -> update_variable_action(var, action_table, decay) end)
    end
  end

  ## Update action for individual variable in 'shared'
  defp update_variable_action(
         %{id: variable_id, initial_size: initial_size} = variable,
         action_table,
         decay
       ) do
    updated_action =
      case get_action(action_table, variable_id) do
        nil ->
          @default_action_value

        current_action ->
          ## Some variables may fail
          current_size =
            try do
              Interface.size(variable)
            catch
              :fail ->
                0
            end

          (initial_size > current_size && current_action + 1) || current_action * decay
      end

    :ets.insert(action_table, {variable_id, updated_action})
  end

  defp get_action(table, variable_id)
       when is_reference(table) and is_reference(variable_id) do
    table
    |> :ets.lookup(variable_id)
    |> then(fn rec ->
      (!Enum.empty?(rec) && elem(hd(rec), 1)) ||
        @default_action_value
    end)
  end
end
