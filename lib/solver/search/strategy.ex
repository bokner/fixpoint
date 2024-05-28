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

        variable_partitions(selected_variable, domain_partitions, variables)
    end
  end

  def partition(variable, value_choice) do
    variable
    |> partition_impl(value_choice)
    |> split_domain_by(variable)
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

  defp variable_partitions(selected_variable, domain_partitions, variables) do
    Enum.map(domain_partitions, fn {domain, constraint} ->
      {Enum.map(variables, fn var ->
        domain_copy =
          ((var.id == selected_variable.id && domain) || var.domain)
          #var.domain
          |> Domain.copy()

        set_domain(var, domain_copy)
      end), constraint}
    end)
  end

  defp split_domain_by(value, variable) do
    domain = Interface.domain(variable)

    try do
      Domain.remove(domain, value)

      {:ok,
       [
         {
          Domain.new(value),
          Equal.new(variable, value)},
         {
          domain,
          NotEqual.new(variable, value)
        }
       ]}
    rescue
      :fail ->
        Logger.error(
          "Failure on partitioning with value #{inspect(value)}, domain: #{inspect(CPSolver.BitVectorDomain.raw(domain))}"
        )

        throw(:fail)
    end
  end
end
