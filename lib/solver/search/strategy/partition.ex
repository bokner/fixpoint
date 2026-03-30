defmodule CPSolver.Search.Partition do
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

  defp partition_impl(variable, value) when is_integer(value) do
    partition_by_fix(variable, value)
  end

  defp partition_impl(variable, value_choice) when is_function(value_choice) do
    partition_impl(variable, value_choice.(variable))
  end

  defp partition_impl(variable, value_choice) when is_atom(value_choice) do
    impl = strategy(value_choice)

    selected_value = impl.select_value(variable)

    case impl.partition(selected_value) do
      reduction when is_function(reduction, 1) ->
        reduction.(variable)

      functions when is_list(functions) ->
        functions
    end
    |> Enum.map(fn
      reduction when is_map(reduction) ->
        reduction

      reduction when is_function(reduction, 1) ->
        %{variable.id => reduction}
    end)
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
  def partition_by_fix(variable, value) when is_integer(value) do
    [
      # Equal.new(variable, value)
      fixed_value_partition(variable, value),
      # NotEqual.new(variable, value)
      removed_value_partition(variable, value)
    ]
  end

  def fixed_value_partition(variable, value) do
    new(
      variable,
      fn variable -> Interface.fix(variable, value) end
    )
  end

  def removed_value_partition(variable, value) do
    new(
      variable,
      fn variable -> Interface.remove(variable, value) end
    )
  end

  def new(variable, reduction) when is_function(reduction, 1) do
    %{variable.id => reduction}
  end
end
