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
        [
          fn domain -> Domain.fix(domain, value) end,
          fn domain -> Domain.remove(domain, value) end,
        ]
      end

      defoverridable initialize: 1, partition: 1
    end
  end
end
