defmodule CPSolver.Search do
  alias CPSolver.DefaultDomain, as: Domain

  alias CPSolver.Search.VariableSelector
  alias CPSolver.Search.Partition
  alias CPSolver.Variable.Interface
  alias CPSolver.Utils.Vector
  alias InPlace.SparseSet

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

  def initialize(brancher_fun, space_data) when is_function(brancher_fun, 3) do
    brancher_fun.(:init, space_data, nil)
  end

  ### Helpers
  def branch(variables, branching, space_data \\ %{})

  def branch(variables, branching, space_data) do
    variables
    |> filter_fixed_variables(space_data)
    |> then(fn unfixed_vars ->
      unfixed_vars
      |> branch_impl(branching, space_data)
      |> then(fn branching -> branching || branch_impl(variables, default_strategy(), space_data) end)
      |> partitions_impl(space_data)
    end)
  end

  defp branch_impl(variables, brancher_fun, space_data) when is_function(brancher_fun, 3) do
    brancher_fun.(:branch, variables, space_data)
  end

  defp branch_impl(variables, brancher_impl, space_data) when is_atom(brancher_impl) do
    if Code.ensure_loaded(brancher_impl) == {:module, brancher_impl} &&
         function_exported?(brancher_impl, :branch, 2) do
      brancher_impl.branch(variables, space_data)
    else
      throw({:unknown_brancher, brancher_impl})
    end
  end

  defp branch_impl(variables, {variable_choice, partition_strategy}, space_data) do
    branch_impl(variables, variable_choice, partition_strategy, space_data)
  end

  defp branch_impl(variables, variable_choice, partition_strategy, space_data) do
    branch_impl(
      variables,
      fn :branch, variables, space_data ->
        variable_value_choice(variables, variable_choice, partition_strategy, space_data)
      end,
      space_data
    )
  end

  def variable_value_choice(variables, variable_choice, partition_strategy, space_data) do
    case VariableSelector.select_variable(variables, space_data, variable_choice) do
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

  # defp filter_fixed_variables(vars, %{unfixed_variables_tracker: tracker} = _space_data) do
  #   ## Update the tracker - delete indices for fixed variables
  #   SparseSet.reduce(tracker, [],
  #     fn idx, acc ->
  #       var = vars[idx - 1]
  #       if Interface.fixed?(var) do
  #         SparseSet.delete(tracker, idx)
  #         acc
  #       else
  #         [var | acc]
  #       end
  #     end)
  #   |> Enum.reverse()

  # end

  defp filter_fixed_variables(vars, _space_data) do
    case Enum.reject(vars, fn var -> Interface.fixed?(var) end) do
      false ->
        throw(:all_vars_fixed)

      unfixed_vars ->
        unfixed_vars
    end
  end

  defp partitions_impl(nil, _space_data) do
    []
  end

  defp partitions_impl(partitions, space_data) when is_list(partitions) do
    Enum.reduce(partitions, [], fn variable_partition, acc ->
      acc ++ variable_partitions_impl(variable_partition, space_data)
    end)
  end

  ## Build partitions for a single variable
  defp variable_partitions_impl(domain_partitions, space_data) do
    Enum.map(List.wrap(domain_partitions), fn partition ->
      build_reduction(partition, space_data)
    end)
  end

  ## Partition is a map %{var_id => reduction}
  ## `reduction is a function that takes a variable
  ## and performs domain reduction.
  ##
  defp build_reduction(partition, _space_data) do
    fn variables ->
      var_array = Vector.new([])

      {variable_copies, domain_changes} =
        Enum.reduce(variables, {var_array, Map.new()}, fn var, {variables_acc, changes_acc} ->
        var_copy = copy_variable(var)

        changes_acc =
          case Map.get(partition, var.id) do
            nil -> changes_acc
            reduction -> Map.put(changes_acc, var.id, reduction.(var_copy))
          end

        {
          Vector.append(variables_acc, var_copy),
          changes_acc
        }
      end)
      %{
          variable_copies: variable_copies,
          domain_changes: domain_changes
      }

    end
  end
end
