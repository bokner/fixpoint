defmodule CPSolver.Search.Strategy do
  alias CPSolver.Search.DomainPartition
  alias CPSolver.Variable
  alias CPSolver.Variable.Interface
  alias CPSolver.DefaultDomain, as: Domain
  alias CPSolver.Search.{VariableChoice, ValueChoice}
  @callback select_variable([Variable.t()]) :: {:ok, Variable.t()} | {:error, any()}
  @callback partition(domain :: Enum.t()) :: {:ok, [Domain.t() | number()]} | {:error, any()}


  def default_strategy() do
    {
      &VariableChoice.first_fail/1,
      &DomainPartition.by_min/1
    }
  end

  def select_variable(variables, variable_choice) do
    variables
    |> Enum.reject(fn v -> Interface.fixed?(v) end)
    |> then(fn [] -> throw(all_vars_fixed_exception())
      unfixed_vars -> variable_choice.(unfixed_vars)
    end)
  end

  def partition(variable, value_choice) do
    value_choice.(variable)
  end

  def branch(variables, variable_choice, value_choice) do
    selected_variable = select_variable(variables, variable_choice)
    domain_partitions = partition(selected_variable, value_choice)
    variable_clones = Enum.map(domain_partitions, fn domain -> set_domain(selected_variable, domain) end)
    variable_partitions(variable_clones, variables)

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

  defp variable_partitions(variable_clones, variables) do
    variables_map = Map.new(variables, fn v -> {v.id, v} end)
    Enum.map(variable_clones, fn clone -> Map.put(variables_map, clone.id, clone) |> Enum.map(fn {_var_id, v} -> v end) end)
  end
end
