defmodule CPSolver.Search.Strategy do
  alias CPSolver.Search.DomainPartition
  alias CPSolver.Variable.Interface
  alias CPSolver.DefaultDomain, as: Domain
  alias CPSolver.Search.VariableSelector.FirstFail

  def default_strategy() do
    {
      :first_fail,
      :indomain_min
    }
  end

  def shortcut(:first_fail) do
    &FirstFail.select_variable/1
  end

  def shortcut(:input_order) do
    &List.first/1
  end

  def shortcut(:indomain_min) do
    &DomainPartition.by_min/1
  end

  def shortcut(:indomain_max) do
    &DomainPartition.by_max/1
  end

  def shortcut(:indomain_random) do
    &DomainPartition.random/1
  end

  def select_variable(variables, variable_choice) when is_atom(variable_choice) do
    select_variable(variables, shortcut(variable_choice))
  end

  def select_variable(variables, variable_choice) when is_function(variable_choice) do
    variables
    |> Enum.reject(fn v -> Interface.fixed?(v) end)
    |> then(fn
      [] -> throw(all_vars_fixed_exception())
      unfixed_vars -> variable_choice.(unfixed_vars)
    end)
  end

  def partition(variable, value_choice) when is_atom(value_choice) do
    shortcut(value_choice).(variable)
  end

  def partition(variable, value_choice) when is_function(value_choice) do
    value_choice.(variable)
  end

  def branch(variables, {variable_choice, partition_strategy}) do
    branch(variables, variable_choice, partition_strategy)
  end

  def branch(variables, variable_choice, partition_strategy) do
    case select_variable(variables, variable_choice) do
      nil ->
        []

      selected_variable ->
        {:ok, domain_partitions} = partition(selected_variable, partition_strategy)
        variable_partitions(selected_variable, domain_partitions, variables)
    end
  end

  def all_vars_fixed_exception() do
    :all_vars_fixed
  end

  def failed_variables_in_search_exception() do
    :failed_variables_in_search
  end

  defp set_domain(variable, domain) do
    Map.put(variable, :domain, Domain.new(domain))
  end

  defp variable_partitions(selected_variable, domain_partitions, variables) do
    Enum.map(domain_partitions, fn domain ->
      Enum.map(variables, fn var ->
        (var.id == selected_variable.id && set_domain(var, domain)) || var
      end)
    end)
  end
end
