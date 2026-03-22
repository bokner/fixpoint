defmodule CPSolver.Search do
  alias CPSolver.DefaultDomain, as: Domain

  alias CPSolver.Search.VariableSelector
  alias CPSolver.Search.Partition

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

  def branch(variables, brancher_fun, space_data) when is_function(brancher_fun, 3) do
    brancher_fun.(:branch, variables, space_data)
    |> partitions_impl(variables, space_data)
    |> List.wrap()
  end

  def branch(variables, brancher_impl, space_data) when is_atom(brancher_impl) do
    if Code.ensure_loaded(brancher_impl) == {:module, brancher_impl}
      && function_exported?(brancher_impl, :branch, 2) do
        brancher_impl.branch(variables, space_data)
        |> partitions_impl(variables, space_data)
    else
      throw({:unknown_brancher, brancher_impl})
    end
  end

  def branch(variables, {variable_choice, partition_strategy}, space_data) do
    branch(variables, variable_choice, partition_strategy, space_data)
  end

  def branch(variables, variable_choice, partition_strategy, space_data) do
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
  defp variable_partitions_impl(%{variable: selected_variable, partitions: domain_partitions}, variables, _space_data) do
    Enum.map(domain_partitions, fn {domain, constraint} ->
      {Arrays.map(variables, fn var ->
         domain_copy =
           ((var.id == selected_variable.id && domain) || var.domain)
           |> Domain.copy()

         set_domain(var, domain_copy)
       end),
       constraint}
    end)
  end

  def partition_record(variable, domain_partitions) do
    %{variable: variable, partitions: domain_partitions}
  end
end
