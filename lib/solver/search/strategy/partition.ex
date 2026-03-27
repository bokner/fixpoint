defmodule CPSolver.Search.Partition do
  alias CPSolver.DefaultDomain, as: Domain

  alias CPSolver.Variable.Interface

  alias CPSolver.Search.ValueSelector.{Min, Max, Random, Split}

  import CPSolver.Utils

  require Logger

  def initialize(partition, _space_data) do
    ## TODO:
    # strategy(partition).initialize(space_data)
    partition
  end

  def partition(variable, value_choice) do
    {:ok, partition_impl(variable, value_choice)}
  end

  defp partition_impl(variable, value) when is_integer(value) do
    partition_by_fix(value, variable)
  end

  defp partition_impl(variable, value_choice) when is_function(value_choice) do
    partition_impl(variable, value_choice.(variable))
  end

  defp partition_impl(variable, value_choice) when is_atom(value_choice) do
    domain = Interface.domain(variable)
    impl = strategy(value_choice)


    selected_value = impl.select_value(variable)

    impl.partition(selected_value)
    |> Enum.map(fn partition_fun ->
      d_copy = Domain.copy(domain)
      domain_changes = partition_fun.(d_copy) |> normalize_domain_changes()
      {
        d_copy,
        %{variable.id => domain_changes}
      }
    end)
  end

  defp normalize_domain_changes({changes, _domain}), do: changes
  defp normalize_domain_changes(changes) when is_atom(changes), do: changes

  defp strategy(:indomain_min) do
    Min
  end

  defp strategy(:indomain_max) do
    Max
  end

  defp strategy(:indomain_random) do
    Random
  end

  defp strategy(:indomain_split) do
    Split
  end

  defp strategy(impl) when is_atom(impl) do
    if Code.ensure_loaded(impl) == {:module, impl} && function_exported?(impl, :select, 2) do
      impl
    else
      throw({:unknown_strategy, impl})
    end
  end

  ## Default partitioning
  def partition_by_fix(value, variable) do

    try do
      remove_changes = Interface.remove(variable, value)
      [
        fixed_partition(value, variable), # Equal.new(variable, value)
        domain_partition(Interface.domain(variable), %{variable.id => remove_changes}), # NotEqual.new(variable, value)
      ]
    catch
    :fail ->
      Logger.error(
        "Failure on partitioning with value #{inspect(value)}, domain: #{domain_values(variable)}}"
      )
      throw(:fail)
    end
  end

  def fixed_partition(value, variable) do
    domain_partition(Domain.new(value), %{variable.id => :fixed})
  end

  def domain_partition(domain, constraint) do
    {domain, constraint}
  end
end
