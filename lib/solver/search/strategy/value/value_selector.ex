defmodule CPSolver.Search.ValueSelector do
  @callback select_value(Variable.t()) :: integer()
  @callback partition(integer()) :: [function()]
  @callback initialize(map()) :: :ok

  defmacro __using__(_) do
    quote do
      alias CPSolver.Search.ValueSelector
      alias CPSolver.Variable.Interface
      alias CPSolver.DefaultDomain, as: Domain

      @behaviour ValueSelector
      def initialize(data) do
        :ok
      end

      def partition(value) do
        fn variable -> CPSolver.Search.Partition.partition_by_fix(variable, value) end
      end

      defoverridable initialize: 1, partition: 1
    end
  end
end
