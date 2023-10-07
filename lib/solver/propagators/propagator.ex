defmodule CPSolver.Propagator do
  @callback filter(args :: list()) :: map() | :stable | :failure
  @callback variables(args :: list()) :: list()
  @callback events() :: list()

  alias CPSolver.Variable
  alias CPSolver.Propagator.Variable, as: PropagatorVariable

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
    PropagatorVariable.reset_variable_ops()

    case mod.filter(args) do
      :stable ->
        :stable

      _res ->
        ## If propagator doesn't explicitly return 'stable',
        ## we retrieve the map of variable operations created by PropagatorVariable wrapper
        case PropagatorVariable.get_variable_ops() do
          {:fail, var} ->
            {:fail, var}

          op_results when is_map(op_results) ->
            process_op_changes(op_results)
        end
    end
  end

  @spec process_op_changes(%{reference() => atom()}) ::
          :stable | {:changed, [{atom(), reference()}]}
  defp process_op_changes(op_results) do
    op_results
    |> Enum.flat_map(fn {var, result} ->
      (result == :no_change && []) || [{result, var}]
    end)
    |> then(fn changes -> (changes == [] && :stable) || {:changed, changes} end)
  end
end
