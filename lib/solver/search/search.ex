defmodule CPSolver.Search do
  alias CPSolver.DefaultDomain, as: Domain

  alias CPSolver.Search.VariableSelector
  alias CPSolver.Search.Partition
  alias CPSolver.Utils.Vector
  alias CPSolver.Variable.UnfixedTracker, as: Tracker

  require Logger

  def default_strategy() do
    CPSolver.Search.DefaultBrancher
  end

  def initialize({variable_choice, value_choice} = _search, space_data) do
    {
      VariableSelector.initialize(variable_choice, space_data),
      Partition.initialize(value_choice, space_data)
    }
  end

  def initialize(brancher_impl, data) when is_atom(brancher_impl) do
    if Code.ensure_loaded(brancher_impl) == {:module, brancher_impl} &&
         function_exported?(brancher_impl, :branch, 2) do
      brancher_impl.initialize(data)
    else
      throw({:unknown_brancher, brancher_impl})
    end
  end

  def initialize(brancher_fun, space_data) when is_function(brancher_fun, 2) do
    brancher_fun.(:init, space_data)
  end

  def branch(branching, space_data) do
    if Tracker.empty?(space_data[:unfixed_variables_tracker]) do
      throw(:all_vars_fixed)
    else
      case branch_impl(branching, space_data) do
        nil ->
          branch_impl(default_strategy(), space_data)

        branching ->
          branching
      end
      |> partitions_impl()
    end
  end

  defp branch_impl(brancher_fun, space_data) when is_function(brancher_fun, 2) do
    brancher_fun.(:branch, space_data)
  end

  defp branch_impl(brancher_impl, space_data) when is_atom(brancher_impl) do
    if Code.ensure_loaded(brancher_impl) == {:module, brancher_impl} &&
         function_exported?(brancher_impl, :branch, 2) do
      space_data
      |> brancher_impl.branch(space_data)
    else
      throw({:unknown_brancher, brancher_impl})
    end
  end

  defp branch_impl({variable_choice, partition_strategy}, space_data) do
    branch_impl(variable_choice, partition_strategy, space_data)
  end

  defp branch_impl(variable_choice, partition_strategy, space_data) do
    branch_impl(
      fn :branch, space_data ->
        variable_value_choice(variable_choice, partition_strategy, space_data)
      end,
      space_data
    )
  end

  def variable_value_choice(variable_choice, partition_strategy, space_data) do
    case VariableSelector.select_variable(space_data, variable_choice) do
      nil ->
        []

      selected_variable ->
        {:ok, domain_partitions} =
          Partition.partition(selected_variable, partition_strategy)

        domain_partitions
    end
  end

  defp copy_variable(%{domain: domain} = variable) do
    Map.put(variable, :domain, Domain.copy(domain))
  end

  defp partitions_impl(nil) do
    []
  end

  defp partitions_impl(partitions) when is_list(partitions) do
    Enum.reduce(partitions, [], fn variable_partition, acc ->
      acc ++ variable_partitions_impl(variable_partition)
    end)
  end

  ## Build partitions for a single variable
  defp variable_partitions_impl(domain_partitions) do
    Enum.map(List.wrap(domain_partitions), fn partition ->
      build_reduction(partition)
    end)
  end

  ## Partition is a map %{var_id => reduction}
  ## `reduction is a function that takes a variable
  ## and performs domain reduction.
  ##
  defp build_reduction(partition) do
    fn %{variables: variables} = space_data ->

      {_idx, variable_copies, domain_changes} =
        Vector.reduce(variables, {0, variables, Map.new()}, fn var,
                                                               {var_idx, variables_acc,
                                                                changes_acc} ->
          var_copy = copy_variable(var)

          changes_acc =
            case Map.get(partition, var.id) do
              nil -> changes_acc
              reduction -> Map.put(changes_acc, var.id, reduction.(var_copy))
            end

          {
            var_idx + 1,
            Vector.update(variables_acc, var_idx, var_copy),
            changes_acc
          }
        end)

      ## Create a copy of "unfixed variables" tracker.
      ##
      tracker_copy =
        case space_data[:unfixed_variables_tracker] do
          nil -> nil
          tracker -> Tracker.copy(tracker)
        end

      %{
        variable_copies: variable_copies,
        domain_changes: domain_changes,
        unfixed_variables_tracker: tracker_copy
      }
    end
  end
end
