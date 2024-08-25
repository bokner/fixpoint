defmodule CPSolver.Propagator do
  @type propagator_event :: :domain_change | :bound_change | :min_change | :max_change | :fixed

  @callback reset(args :: list(), state :: map()) :: map() | nil
  @callback reset(args :: list(), state :: map(), opts :: Keyword.t()) :: map() | nil
  @callback filter(args :: list()) :: {:state, map()} | :stable | :fail | propagator_event()
  @callback filter(args :: list(), state :: map() | nil) ::
              {:state, map()} | :stable | :fail | propagator_event()
  @callback filter(args :: list(), state :: map() | nil, changes :: map()) ::
              {:state, map()} | :stable | :fail | propagator_event()
  @callback entailed?(Propagator.t(), state :: map() | nil) :: boolean()
  @callback failed?(Propagator.t(), state :: map() | nil) :: boolean()

  @callback variables(args :: list()) :: list()
  @callback arguments(args :: list()) :: Arrays.t()

  alias CPSolver.Variable
  alias CPSolver.Variable.Interface
  alias CPSolver.Variable.View
  alias CPSolver.Propagator.Variable, as: PropagatorVariable
  alias CPSolver.DefaultDomain, as: Domain
  alias CPSolver.Propagator.ConstraintGraph
  alias CPSolver.Utils.TupleArray
  alias CPSolver.Utils

  defmacro __using__(_) do
    quote do
      alias CPSolver.Propagator
      alias CPSolver.Variable.Interface
      alias CPSolver.DefaultDomain, as: Domain
      import CPSolver.Propagator.Variable

      @behaviour Propagator

      def new(args) do
        Propagator.new(__MODULE__, arguments(args))
      end

      def arguments(args) do
        args
      end

      def reset(args, state, _opts) do
        reset(args, state)
      end

      def reset(_args, state) do
        state
      end

      def filter(args, _propagator_state) do
        filter(args)
      end

      def filter(args, propagator_state, _incoming_changes) do
        filter(args, propagator_state)
      end

      def entailed?(args, propagator_state) do
        !propagator_state[:active?]
      end

      def failed?(args, _propagator_state) do
        false
      end

      def variables(args) do
        Propagator.default_variables_impl(args)
      end

      defoverridable arguments: 1,
                     variables: 1,
                     reset: 2,
                     reset: 3,
                     filter: 2,
                     filter: 3,
                     failed?: 2,
                     entailed?: 2
    end
  end

  def propagator_events() do
    [:domain_change, :bound_change, :min_change, :max_change, :fixed]
  end

  def default_variables_impl(args) do
    args
    |> Enum.reject(fn arg -> is_constant_arg(arg) end)
  end

  def new(mod, args, opts \\ []) do
    id = Keyword.get_lazy(opts, :id, fn -> make_ref() end)
    name = Keyword.get(opts, :name, id)

    %{
      id: id,
      name: name,
      mod: mod,
      args: args
    }
  end

  def variables(%{mod: mod, args: args} = _propagator) do
    args
    |> Enum.with_index()
    |> Enum.map(fn {arg, idx} ->
      (is_constant_arg(arg) && arg) ||
        Map.put(arg, :arg_position, idx)
    end)
    |> mod.variables()
  end

  def reset(%{mod: mod, args: args} = propagator, opts \\ []) do
    Map.put(propagator, :state, mod.reset(args, Map.get(propagator, :state), opts))
  end

  def dry_run(%{args: args} = propagator, opts \\ []) do
    staged_propagator = %{propagator | args: copy_args(args)}
    {staged_propagator, filter(staged_propagator, opts)}
  end

  def filter(%{mod: mod, args: args} = propagator, opts \\ []) do
    PropagatorVariable.reset_variable_ops()
    state = propagator[:state]

    # IO.inspect({self(), opts, label: :filter_opts})

    ## Propagation changes
    ## The propagation may reshedule the filtering and pass the changes that woke
    ## the propagator.
    incoming_changes = Keyword.get(opts, :changes) || %{}
    ## We will reset the state if required.
    ## Reset will be forced when the space starts propagation.
    reset? = Keyword.get(opts, :reset?, false)

    try do
      state = (reset? && mod.reset(args, state, opts)) || state

      case mod.filter(args, state, incoming_changes) do
        :fail ->
          :fail

        :stable ->
          :stable

        result ->
          get_filter_changes(result)
      end
    catch
      :error, error ->
        {:filter_error, {mod, error}}
        |> IO.inspect(__STACKTRACE__)

      :fail ->
        :fail
    end

    # |> tap(fn res -> IO.inspect({mod, res}, label: :"PROPAGATOR") end)
  end

  ## Check if propagator is entailed (i.e., all variables are fixed)
  def entailed?(%{mod: mod, args: args} = propagator) do
    mod.entailed?(args, propagator[:state])
  end

  def failed?(%{mod: mod, args: args} = propagator) do
    mod.failed?(args, propagator[:state])
  end

  ## How propagator events map to domain events
  def to_domain_events(:domain_change) do
    [:domain_change | to_domain_events(:bound_change)]
  end

  def to_domain_events(:bound_change) do
    [:min_change, :max_change, :bound_change, :fixed]
  end

  def to_domain_events(:min_change) do
    [:min_change, :fixed]
  end

  def to_domain_events(:max_change) do
    [:max_change, :fixed]
  end

  def to_domain_events(_fixed) do
    [:fixed]
  end

  @spec get_filter_changes(term()) ::
          %{:changes => map(), :state => map(), active?: boolean()}
  defp get_filter_changes(propagator_active?) when is_boolean(propagator_active?) do
    %{
      changes: PropagatorVariable.get_variable_ops(),
      active?: propagator_active?,
      state: nil
    }
  end

  defp get_filter_changes({:state, state}) do
    get_filter_changes(true)
    |> Map.put(:state, state)
    |> Map.put(:active?, Map.get(state, :active?, true))
  end

  defp get_filter_changes(result) do
    get_filter_changes(result != :passive)
  end

  def bind_to_variables(propagator, %Graph{} = constraint_graph, var_field) do
    bind_to_variables_impl(
      propagator,
      fn var_id -> ConstraintGraph.get_variable(constraint_graph, var_id) end,
      var_field
    )
  end

  def bind_to_variables(propagator, variable_map, var_field) when is_map(variable_map) do
    bind_to_variables_impl(propagator, fn var_id -> Map.get(variable_map, var_id) end, var_field)
  end

  defp bind_to_variables_impl(propagator, getter_fun, var_field) do
    bound_args =
      propagator.args
      |> arg_map(fn arg -> bind_to_variable(arg, getter_fun, var_field) end)

    Map.put(propagator, :args, bound_args)
  end

  defp copy_variable(%Variable{domain: domain} = var) do
    %{var | domain: Domain.copy(domain)}
  end

  defp copy_variable(%View{variable: variable} = view) do
    Map.put(view, :variable, copy_variable(variable))
  end

  defp bind_to_variable(%Variable{id: id} = propagator_var, variable_getter_fun, var_field)
       when is_function(variable_getter_fun, 1) do
    source_var = variable_getter_fun.(id)
    Map.put(propagator_var, var_field, Map.get(source_var, var_field))
  end

  defp bind_to_variable(%View{variable: variable} = view, variable_getter_fun, var_field) do
    bound_var = bind_to_variable(variable, variable_getter_fun, var_field)
    Map.put(view, :variable, bound_var)
  end

  defp bind_to_variable(const, _indexed_variables, _var_field) do
    const
  end

  def is_constant_arg(%Variable{} = _arg) do
    false
  end

  def is_constant_arg(%View{} = _arg) do
    false
  end

  def is_constant_arg(_other) do
    true
  end

  def arg_at(args, pos) when is_tuple(args) do
    TupleArray.at(args, pos)
  end

  def arg_at(args, pos) do
    Arrays.get(args, pos)
  end

  def arg_map(args, mapper) when is_function(mapper) and is_list(args) do
    Enum.map(args, mapper)
  end

  def arg_map(args, mapper) when is_function(mapper) and is_tuple(args) do
    TupleArray.map(args, mapper)
  end

  def arg_map(args, mapper) when is_function(mapper) do
    Arrays.map(args, mapper)
  end

  def args_to_list(args) when is_tuple(args) do
    Tuple.to_list(args)
  end

  def args_to_list(args) do
    args
  end

  def propagator_domain_values(%{args: args} = _p) do
    arg_map(args, fn arg ->
      (is_constant_arg(arg) && arg) || {Interface.variable(arg).name, Utils.domain_values(arg)}
    end)
  end

  defp copy_args(args) do
    arg_map(args, fn arg ->
      (is_constant_arg(arg) && arg) ||
        copy_variable(arg)
    end)
  end
end
