defmodule CPSolver.Propagator do
  @callback filter(variables :: list()) :: map() | :stable | :failure
  @callback variables(args :: list()) :: list()

  defmacro __using__(_) do
    quote do
      @behaviour CPSolver.Propagator
      def variables(args) do
        args
      end

      defoverridable variables: 1
    end
  end
end
