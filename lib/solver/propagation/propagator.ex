defmodule CPSolver.Propagator do
  @callback filter(args :: list()) :: map() | :stable | :failure
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

  def normalize({_mod, args} = propagator) when is_list(args) do
    propagator
  end

  def normalize(propagator) when is_tuple(propagator) do
    [mod | args] = Tuple.to_list(propagator)
    {mod, args}
  end
end
