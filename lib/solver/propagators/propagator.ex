defmodule CPSolver.Propagator do
  @type propagator_event :: :domain_change | :bound_change | :min_change | :max_change | :fixed

  @callback new(args :: list()) :: Propagator.t()
  @callback filter(args :: list()) :: map() | :stable | :fail | propagator_event()
  @callback variables(args :: list()) :: list()

  alias CPSolver.Variable
  alias CPSolver.Propagator.Variable, as: PropagatorVariable

  defmacro __using__(_) do
    quote do
      alias CPSolver.Propagator
      import CPSolver.Propagator.Variable
      @behaviour Propagator

      def new(args) do
        Propagator.new(__MODULE__, args)
      end

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

  def new(mod, args) do
    {mod, args}
  end

  @spec normalize([Propagator.t()]) :: %{reference() => Propagator.t()}

  def normalize(propagators) when is_list(propagators) do
    propagators
    |> Enum.map(&normalize/1)
    |> Map.new(fn p -> {make_ref(), p} end)
  end

  def normalize({_mod, args} = propagator) when is_list(args) do
    propagator
  end

  def normalize(propagator) when is_tuple(propagator) do
    [mod | args] = Tuple.to_list(propagator)
    normalize({mod, args})
  end

  def filter({_mod, _args} = propagator) do
    filter(propagator, nil)
  end

  def filter({mod, args} = _propagator, id) do
    filter(mod, args, id)
  end

  def filter(mod, args, _id \\ nil) do
    PropagatorVariable.reset_variable_ops()

    try do
      mod.filter(args)
    catch
      {:fail, var_id} ->
        {:fail, var_id}
    else
      :stable ->
        :stable

      _res ->
        ## If propagator doesn't explicitly return 'stable',
        ## we retrieve the map of variable operation results created by PropagatorVariable wrapper
        get_filter_changes()
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

  @spec get_filter_changes() ::
          :stable | {:changed, [{atom(), reference()}]}
  defp get_filter_changes() do
    filter_changes = PropagatorVariable.get_variable_ops()
    (filter_changes && {:changed, filter_changes}) || :stable
  end
end
