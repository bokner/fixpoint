defmodule CPSolver.Search do
  alias CPSolver.DefaultDomain, as: Domain

  alias CPSolver.Search.VariableSelector
  alias CPSolver.Search.Partition

  require Logger

  def default_strategy() do
    {
      :first_fail,
      :indomain_min
    }
  end

  def initialize({variable_choice, value_choice} = _search, space_data) do
    {
      VariableSelector.initialize(variable_choice, space_data),
      Partition.initialize(value_choice, space_data)
    }
  end

  ### Helpers

  def branch(variables, {variable_choice, partition_strategy}, data \\ %{}) do
    branch(variables, variable_choice, partition_strategy, data)
  end

  def branch(variables, variable_choice, partition_strategy, data) do
    case VariableSelector.select_variable(variables, data, variable_choice) do
      nil ->
        []

      selected_variable ->
        {:ok, domain_partitions} =
          Partition.partition(selected_variable, partition_strategy)

        partitions(selected_variable, domain_partitions, variables, data)
    end
  end

  defp set_domain(variable, domain) do
    Map.put(variable, :domain, domain)
  end

  defp partitions(selected_variable, domain_partitions, variables, data) when is_list(variables) do
    partitions(selected_variable, domain_partitions, Arrays.new(variables, implementation: Aja.Vector), data)
  end

  defp partitions(selected_variable, domain_partitions, variables, _data) do
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
end
