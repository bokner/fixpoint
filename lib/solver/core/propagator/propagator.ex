defmodule CPSolver.Propagator do
  @type propagator_event :: :domain_change | :bound_change | :min_change | :max_change | :fixed

  @callback new(args :: list()) :: Propagator.t()
  @callback filter(args :: list()) :: map() | :stable | :fail | propagator_event()
  @callback variables(args :: list()) :: list()

  alias CPSolver.Variable
  alias CPSolver.Variable.View
  alias CPSolver.Propagator.Variable, as: PropagatorVariable
  alias CPSolver.DefaultDomain, as: Domain
  alias CPSolver.Variable.Interface

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

  def new(mod, args, opts \\ []) do
    id = Keyword.get_lazy(opts, :id, fn -> make_ref() end)
    name = Keyword.get(opts, :name, id)

    %{
      id: id,
      name: name,
      mod: mod,
      args:
        Enum.map(args, fn
          %Variable{domain: domain} = arg ->
            arg
            |> Map.drop([:domain])
            |> Map.put(:fixed?, Domain.fixed?(domain))

          const ->
            const
        end)
    }
  end

  def filter(%{mod: mod, args: args} = _propagator, opts \\ []) do
    PropagatorVariable.reset_variable_ops()
    store = Keyword.get(opts, :store)

    try do
      args
      |> List.flatten()
      |> bind_to_store(store)
      |> mod.filter()
    catch
      {:fail, var_id} ->
        {:fail, var_id}
    else
      :stable ->
        :stable

      :fail ->
        :fail

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

  def bind_to_variables(propagator, indexed_variables) do
    bound_args =
      propagator.args
      |> List.flatten()
      |> Enum.map(fn arg -> bind_to_variable(arg, indexed_variables) end)

    Map.put(propagator, :args, bound_args)
  end

  defp bind_to_variable(%Variable{id: id} = var, indexed_variables) do
    var_idx = Map.get(indexed_variables, id).index
    Map.put(var, :index, var_idx)
  end

  defp bind_to_variable(%View{variable: variable} = view, indexed_variables) do
    bound_var = bind_to_variable(variable, indexed_variables)
    Map.put(view, :variable, bound_var)
  end

  defp bind_to_variable(const, _indexed_variables) do
    const
  end

  defp bind_to_store(args, nil) do
    args
  end

  defp bind_to_store(args, store) do
    args
    |> Enum.map(fn
      v when is_struct(v, Variable) or is_struct(v, View) ->
        Interface.bind(v, store)

      const ->
        const
    end)
  end
end
