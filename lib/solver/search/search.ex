defmodule CPSolver.Search do
  alias CPSolver.Search.VariableSelector
  alias CPSolver.Search.Partition
  alias CPSolver.DefaultDomain, as: Domain

  require Logger

  def default_strategy() do
    {
      :first_fail,
      :indomain_min
    }
  end

  def initialize({variable_choice, partition} = _search, space_data) do
    VariableSelector.initialize(variable_choice, space_data)
    Partition.initialize(partition, space_data)
  end

  def branch(variables, {variable_choice, partition_strategy}) do
    branch(variables, variable_choice, partition_strategy, %{})
  end

  def branch(variables, {variable_choice, partition_strategy}, data) do
    branch(variables, variable_choice, partition_strategy, data)
  end

  def branch(variables, variable_choice, partition_strategy, data \\ %{})

  def branch(variables, variable_choice, partition_strategy, data)
      when is_function(variable_choice, 2) do
    variable_choice_arity1 = fn variables -> variable_choice.(variables, data) end
    branch(variables, variable_choice_arity1, partition_strategy, data)
  end

  def branch(variables, variable_choice, partition_strategy, data)
      when is_function(variable_choice, 1) do
    case VariableSelector.select_variable(variables, variable_choice, data) do
      nil ->
        []

      selected_variable ->
        {:ok, domain_partitions} =
          Partition.partition(selected_variable, partition_strategy)

        variable_partitions(selected_variable, domain_partitions, variables)
    end
  end

  defp variable_partitions(selected_variable, domain_partitions, variables) do
    Enum.map(domain_partitions, fn {domain, constraint} ->
      {Enum.map(variables, fn var ->
         domain_copy =
           ((var.id == selected_variable.id && domain) || var.domain)
           # var.domain
           |> Domain.copy()

         set_domain(var, domain_copy)
       end), constraint}
    end)
  end

  defp set_domain(variable, domain) do
    Map.put(variable, :domain, domain)
  end

end
