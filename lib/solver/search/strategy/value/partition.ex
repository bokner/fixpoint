defmodule CPSolver.Search.Partition do
  alias CPSolver.DefaultDomain, as: Domain

  alias CPSolver.Variable.Interface

  alias CPSolver.Search.ValueSelector.{Min, Max, Random, Split}

  require Logger

  def initialize(partition, _space_data) do
    ## TODO:
    # strategy(partition).initialize(space_data)
    partition
  end

  def partition(variable, value_choice) do
    {:ok, partition_impl(variable, value_choice)}
  end

  defp partition_impl(variable, value_choice) when is_function(value_choice) do
    value_choice.(variable)
    |> partition_by_fix(variable)
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
  defp partition_by_fix(value, variable) do
    domain = Interface.domain(variable)

    try do
      {remove_changes, _domain} = Domain.remove(domain, value)

       [
         {
           Domain.new(value),
           %{variable.id => :fixed}
           # Equal.new(variable, value)
         },
         {
           domain,
           %{variable.id => remove_changes}
           # NotEqual.new(variable, value)
         }
       ]
    rescue
      :fail ->
        Logger.error(
          "Failure on partitioning with value #{inspect(value)}, domain: #{inspect(CPSolver.BitVectorDomain.raw(domain))}"
        )

        throw(:fail)
    end
  end
end
