defmodule CPSolver.Search.Strategy do
  alias CPSolver.Variable.Interface
  alias CPSolver.Search.VariableSelector.FirstFail
  alias CPSolver.DefaultDomain, as: Domain
  alias CPSolver.Constraint.{Equal, NotEqual}

  alias CPSolver.Search.ValueSelector.{Min, Max, Random}

  require Logger

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
    fn variables ->
      Enum.sort_by(variables, fn %{index: idx} -> idx end)
      |> List.first()
    end
  end

  def shortcut(:indomain_min) do
    Min
  end

  def shortcut(:indomain_max) do
    Max
  end

  def shortcut(:indomain_random) do
    Random
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

  defp partition_impl(variable, value_choice) when is_atom(value_choice) do
    shortcut(value_choice).select_value(variable)
  end

  defp partition_impl(variable, value_choice) when is_function(value_choice) do
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
        {:ok, domain_partitions} =
          partition(selected_variable, partition_strategy)

        variable_partitions(domain_partitions, variables)
    end
  end

  def partition(variable, value_choice) do
    variable
    |> partition_impl(value_choice)
    |> branching_constraints(variable)
  end

  def all_vars_fixed_exception() do
    :all_vars_fixed
  end

  def failed_variables_in_search_exception() do
    :failed_variables_in_search
  end

  defp set_domain(variable, domain) do
    Map.put(variable, :domain, domain)
  end

  defp variable_partitions(domain_partitions, variables) do
    Enum.map(domain_partitions, fn constraint ->
      {Enum.map(variables, fn var ->
         set_domain(var, Domain.copy(var.domain))
       end), constraint}
    end)
  end

  defp branching_constraints(value, variable) do
      {:ok,
       [
           Equal.new(variable, value),
           NotEqual.new(variable, value)
       ]}
    end
end
