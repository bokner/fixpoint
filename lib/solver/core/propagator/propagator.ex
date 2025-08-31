defmodule CPSolver.Propagator do
  @type propagator_event :: :domain_change | :bound_change | :min_change | :max_change | :fixed

  @callback reset(args :: list(), state :: map()) :: map() | nil
  @callback reset(args :: list(), state :: map(), opts :: Keyword.t()) :: map() | nil
  @callback bind(Propagator.t(), source :: any(), variable_field :: atom()) :: Propagator.t()
  @callback filter(args :: list(), state :: map(), changes :: map()) ::
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
  alias CPSolver.Common

  require Logger

  defmacro __using__(_) do
    quote do
      alias CPSolver.Propagator
      alias CPSolver.Variable.Interface
      alias CPSolver.DefaultDomain, as: Domain
      import CPSolver.Propagator.Variable
      import CPSolver.Utils

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

      def bind(%{args: args} = propagator, source, var_field) do
        Map.put(propagator, :args, Propagator.bind_to_variables(args, source, var_field))
      end

      def entailed?(args, propagator_state) do
        false
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
                     bind: 3,
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
      args: args,
      state: nil,
      variable_positions:
        mod.variables(Enum.to_list(args))
        |> Enum.with_index(0)
        |> Map.new(fn {var, pos} ->
          {Interface.id(var), pos}
        end)
    }
  end

  def variables(%{mod: mod, args: args} = _propagator) do
    mod.variables(Enum.to_list(args))
  end

  def reset(%{mod: mod, args: args} = propagator, opts \\ []) do
    update_state(propagator, mod.reset(args, Map.get(propagator, :state), opts))
  end

  def update_state(propagator, state) do
    Map.put(propagator, :state, state)
  end

  def bind(%{mod: mod} = propagator, source, var_field \\ :domain) do
    mod.bind(propagator, source, var_field)
  end

  def dry_run(%{args: args} = propagator, opts \\ []) do
    staged_propagator = %{propagator | args: copy_args(args)}
    {staged_propagator, filter(staged_propagator, opts)}
  end

  def filter(%{mod: mod} = propagator, opts \\ []) do
    try do
      propagator = maybe_reset_state(propagator, opts)
      do_filter(propagator, Keyword.get(opts, :changes) || %{})
    catch
      :error, error ->
        {:filter_error, {mod, error}}
        |> tap(fn _ -> Logger.error(%{mod: mod, error: error, stacktrace: __STACKTRACE__}) end)

      :fail ->
        :fail
    end
    |> tap(fn result ->
      case Keyword.get(opts, :debug) do
        debug_fun when is_function(debug_fun) ->
          debug_fun.(propagator, Keyword.drop(opts, [:debug]), result)

        nil ->
          nil
      end
    end)
    |> tap(fn _ -> reset_filter_changes() end)
  end

  defp maybe_reset_state(%{mod: mod, args: args, state: state} = propagator, opts) do
    ## We will reset the state if required.
    ## Reset will be forced on all propagators when the space starts propagation.
    Keyword.get(opts, :reset?)
    && Map.put(propagator, :state, mod.reset(args, state, opts))
    || propagator

  end

  defp positional_changes(domain_changes, positions_map) do
    ## Propagation changes is a var_ref => domain_change map
    ## For performance considerations, it has to be transformed to
    ## var_position => domain_change map,
    ## where `var_position is a position in  propagator's argument list.
    ##
    Enum.reduce(domain_changes, Map.new(),
      fn {var_id, domain_change}, positional_changes_acc ->
      position = (is_integer(var_id) && var_id) || Map.get(positions_map, var_id)

      (position && Map.put(positional_changes_acc, position, domain_change)) ||
      positional_changes_acc
    end)

  end

  defp do_filter(%{mod: mod, args: args, state: state, variable_positions: positions} = _propagator,
    domain_changes) do
      ### The propagator filtering can return:
      ## - :fail
      ##   Meaning the propagator thinks it has found inconsistencies
      ##   (for instance, Circuit propagator concludes there is no possible way to have a hamiltonian cycle)
      ##   given current variable domains
      ## - :stable
      ##   Propagator claims that filtering resulted neither in variable domain changes nor
      ##   propagator state.
      ##
      ## - :passive
      ##   Propagator claims it won't be able to do further reductions
      ##   of variable domains regardless of their current state.
      ##   Note: in this case, the state of propagator is irrelevant, as it will be excluded
      ##   from any further propagations.
      ##
      ## - {:state, new_state}
      ##   Propagator has updated it's state as a result of filtering.
      ##
      ## -any other result
      ##   The propagator didn't change it's state, but it's possible there were
      ##   changes in variable domains.
      ##
      incoming_changes = positional_changes(domain_changes, positions)

      case mod.filter(args, state, incoming_changes) do
        :fail ->
          :fail
        :stable ->
          %{changes: %{}, state: state, active?: true}

        result ->
          case result do
            :passive ->
              %{active?: false, state: nil}
            {:state, updated_state} ->
              %{active?: Map.get(updated_state, :active?, true), state: updated_state}
            _ ->
              %{active?: true, state: state}
          end
          |> Map.put(:changes, reset_filter_changes() || %{})
        end
  end

  def reset_filter_changes() do
    PropagatorVariable.reset_variable_ops()
  end

  def get_filter_changes() do
    PropagatorVariable.get_variable_ops() || %{}
  end

  def merge_changes(changes1, changes2) do
    Map.merge(changes1, changes2,
      fn _var_id, domain_change1, domain_change2 ->
        Common.stronger_domain_change(domain_change1, domain_change2)
      end)
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

  def bind_to_variables(args, variable_source, var_field) do
    arg_map(args, fn arg ->
      bind_to_variable(arg, variable_source, var_field)
    end)
  end

  def bind_to_variable(%Variable{id: id} = propagator_var, variable_source, var_field) do
    source_var = get_variable(variable_source, id)
    Map.put(propagator_var, var_field, Map.get(source_var, var_field))
  end

  def bind_to_variable(%View{variable: variable} = view, variable_source, var_field) do
    bound_var = bind_to_variable(variable, variable_source, var_field)
    Map.put(view, :variable, bound_var)
  end

  def bind_to_variable(const, _variable_source, _var_field) do
    const
  end

  defp get_variable(constraint_graph, var_id) do
    ConstraintGraph.get_variable(constraint_graph, var_id)
  end

  defp copy_variable(%Variable{domain: domain} = var) do
    %{var | domain: Domain.copy(domain)}
  end

  defp copy_variable(%View{variable: variable} = view) do
    Map.put(view, :variable, copy_variable(variable))
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

  def arg_at(args, pos) when is_list(args) do
    Enum.at(args, pos)
  end

  def arg_at(args, pos) do
       Arrays.get(args, pos)
  end

  def arg_map(%{args: args} = _propagator, mapper) do
    arg_map(args, mapper)
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

  def arg_size(args) when is_tuple(args) do
    Tuple.to_list(args) |> length
  end

  def arg_size(args) when is_list(args) do
    length(args)
  end

  def arg_size(args) do
       Arrays.size(args)
  end


  def args_to_list(args) when is_tuple(args) do
    Tuple.to_list(args)
  end

  def args_to_list(args) do
    args
  end

  defp copy_args(args) do
    arg_map(args, fn arg ->
      (is_constant_arg(arg) && arg) ||
        copy_variable(arg)
    end)
  end
end
