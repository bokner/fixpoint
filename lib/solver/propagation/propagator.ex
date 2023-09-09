defmodule CPSolver.Propagator do
  @callback filter(variables :: list()) :: map() | :stable | :failure
  @callback variables(args :: list()) :: list()
  @callback events() :: list()

  defmacro __using__(_) do
    quote do
      @behaviour CPSolver.Propagator
      def variables(args) do
        args
      end

      ## Events that trigger propagation
      def events() do
        CPSolver.Common.domain_changes()
      end

      defoverridable variables: 1
      defoverridable events: 0
    end
  end
end
