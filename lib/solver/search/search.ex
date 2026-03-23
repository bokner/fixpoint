defmodule CPSolver.Search do
  alias CPSolver.DefaultDomain, as: Domain

  alias CPSolver.Search.VariableSelector
  alias CPSolver.Search.Partition
  alias CPSolver.Variable.Interface

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
    if Code.ensure_loaded(brancher_impl) == {:module, brancher_impl}
      && function_exported?(brancher_impl, :branch, 2) do
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
    |> branch_impl(branching, space_data)
  end

  defp branch_impl(variables, brancher_fun, space_data) when is_function(brancher_fun, 3) do
    variables
    |> filter_fixed_variables()
    |> then(fn unfixed_vars ->
      brancher_fun.(:branch, unfixed_vars, space_data)
      |> partitions_impl(variables, space_data)
    end)
  end

  defp branch_impl(variables, brancher_impl, space_data) when is_atom(brancher_impl) do
    if Code.ensure_loaded(brancher_impl) == {:module, brancher_impl}
      && function_exported?(brancher_impl, :branch, 2) do
        variables
        |> filter_fixed_variables()
        |> brancher_impl.branch(space_data)
        |> partitions_impl(variables, space_data)
    else
      throw({:unknown_brancher, brancher_impl})
    end
  end

  defp branch_impl(variables, {variable_choice, partition_strategy}, space_data) do
    branch_impl(variables, variable_choice, partition_strategy, space_data)
  end

  defp branch_impl(variables, variable_choice, partition_strategy, space_data) do
    variable_value_choice(variables, variable_choice, partition_strategy, space_data)
    |> partitions_impl(variables, space_data)
  end

  def variable_value_choice(variables, variable_choice, partition_strategy, space_data) do
    case VariableSelector.select_variable(variables, space_data, variable_choice) do
      nil ->
        []

      selected_variable ->
        {:ok, domain_partitions} =
          Partition.partition(selected_variable, partition_strategy)
          List.wrap(partition_record(selected_variable, domain_partitions))
    end
  end

  defp set_domain(variable, domain) do
    Map.put(variable, :domain, domain)
  end

  defp filter_fixed_variables(vars) do
    case Enum.reject(vars, fn var -> Interface.fixed?(var) end) do
      [] -> throw(:all_vars_fixed)
      unfixed_vars ->
        unfixed_vars
      end
  end

  defp partitions_impl(nil, _variables, _space_data) do
    []
  end

  defp partitions_impl(partitions, variables, space_data) when is_list(partitions) do
    variables = Arrays.new(variables, implementation: Aja.Vector)
    Enum.reduce(partitions, [], fn variable_partition, acc ->
      acc ++ variable_partitions_impl(variable_partition, variables, space_data)
    end)
  end

  ## Build partitions for a single variable
  defp variable_partitions_impl(%{variable_id: selected_variable_id, partitions: domain_partitions}, variables, _space_data) do
    Enum.map(domain_partitions, fn {domain, constraint} ->
      {Arrays.map(variables, fn var ->
         domain_copy =
           ((var.id == selected_variable_id && domain) || var.domain)
           |> Domain.copy()

         set_domain(var, domain_copy)
       end),
       constraint}
    end)
  end

  def partition_record(variable, domain_partitions) do
    %{variable_id: variable.id, partitions: domain_partitions}
  end
end
