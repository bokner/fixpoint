defmodule CPSolver.Search.Partition do

  alias CPSolver.DefaultDomain, as: Domain

  alias CPSolver.Variable.Interface

  alias CPSolver.Search.ValueSelector.{Min, Max, Random}

  require Logger

  def initialize(partition, space_data) do
    strategy(partition).initialize(space_data)
  end

  def partition(variable, value_choice) do
    variable
    |> partition_impl(value_choice)
    |> split_domain_by(variable)
  end

  defp partition_impl(variable, value_choice) when is_function(value_choice) do
    value_choice.(variable)
  end

  defp partition_impl(variable, value_choice) when is_atom(value_choice) do
    strategy(value_choice).select_value(variable)
  end

  defp strategy(:indomain_min) do
    Min
  end

  defp strategy(:indomain_max) do
    Max
  end

  defp strategy(:indomain_random) do
    Random
  end

  defp split_domain_by(value, variable) do
    domain = Interface.domain(variable)

    try do
      {remove_changes, _domain} = Domain.remove(domain, value)

      {:ok,
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
