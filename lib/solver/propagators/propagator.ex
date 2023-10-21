defmodule CPSolver.Propagator do
  @type propagator_event :: :domain_change | :bound_change | :min_change | :max_change | :fixed

  @callback filter(args :: list()) :: map() | :stable | :failure
  @callback variables(args :: list()) :: list()

  alias CPSolver.Variable
  alias CPSolver.Propagator.Variable, as: PropagatorVariable

  defmacro __using__(_) do
    quote do
      alias CPSolver.Propagator
      import CPSolver.Propagator.Variable
      @behaviour Propagator
      def variables(args) do
        Propagator.default_variables_impl(args)
      end

      defoverridable variables: 1
    end
  end

  def propagator_events() do
    [:domain_change, :bound_change, :min_change, :max_change, :fixed]
  end

  def default_variables_impl(args) do
    args
    |> Enum.filter(fn
      %Variable{} -> true
      _ -> false
    end)
  end

  @spec normalize([Propagator.t()]) :: %{reference() => Propagator.t()}

  def normalize(propagators) when is_list(propagators) do
    propagators
    |> Enum.map(&normalize/1)
    |> Enum.uniq()
    |> Map.new(fn p -> {make_ref(), p} end)
  end

  def normalize({_mod, args} = propagator) when is_list(args) do
    propagator
  end

  def normalize(propagator) when is_tuple(propagator) do
    [mod | args] = Tuple.to_list(propagator)
    normalize({mod, args})
  end

  def filter(mod, args, id \\ nil) do
    PropagatorVariable.reset_variable_ops()
    PropagatorVariable.set_propagator_id(id)

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

  ## How propagator events map to domain events
  def to_domain_events(:domain_change) do
    [:domain_change, :min_change, :max_change, :fixed]
  end

  def to_domain_events(:bound_change) do
    [:min_change, :max_change, :fixed]
  end

  def to_domain_events(:min_change) do
    [:min_change, :fixed]
  end

  def to_domain_events(:max_change) do
    [:max_change, :fixed]
  end

  def to_domain_events(:fixed) do
    [:fixed]
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
