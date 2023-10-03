defmodule CPSolver.Propagator do
  @callback filter(args :: list()) :: map() | :stable | :failure
  @callback variables(args :: list()) :: list()
  @callback events() :: list()

  alias CPSolver.Variable

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

  def normalize(propagators, store, store_impl) when is_list(propagators) do
    propagators
    |> Enum.map(fn p -> normalize(p, store, store_impl) end)
    |> Enum.uniq()
  end

  def normalize({mod, args} = _propagator, store, store_impl) when is_list(args) do
    {mod,
     Enum.map(
       args,
       fn
         %Variable{} = arg ->
           arg
           |> Map.put(:store, store)
           |> Map.put(:store_impl, store_impl)

         const ->
           const
       end
     )}
  end

  def normalize(propagator, store, store_impl) when is_tuple(propagator) do
    [mod | args] = Tuple.to_list(propagator)
    normalize({mod, args}, store, store_impl)
  end

  def filter(mod, args) do
    mod.filter(args)
  end
end
