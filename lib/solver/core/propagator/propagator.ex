defmodule CPSolver.Propagator do
  @type propagator_event :: :domain_change | :bound_change | :min_change | :max_change | :fixed

  @callback new(args :: list()) :: Propagator.t()
  @callback update(Propagator.t(), changes: any()) :: Propagator.t()
  @callback filter(args :: list()) :: map() | :stable | :fail | propagator_event()
  @callback filter(args :: list(), state :: map() | nil) ::
              map() | :stable | :fail | propagator_event()
  @callback variables(args :: list()) :: list()

  alias CPSolver.Variable
  alias CPSolver.Variable.View
  alias CPSolver.Propagator.Variable, as: PropagatorVariable
  alias CPSolver.DefaultDomain, as: Domain
  alias CPSolver.Variable.Interface
  alias CPSolver.ConstraintStore

  defmacro __using__(_) do
    quote do
      alias CPSolver.Propagator
      alias CPSolver.Variable.Interface
      alias CPSolver.DefaultDomain, as: Domain
      import CPSolver.Propagator.Variable

      @behaviour Propagator

      def new(args) do
        Propagator.new(__MODULE__, args)
      end

      def update(propagator, _changes) do
        propagator
      end

      def filter(args, _propagator_state) do
        filter(args)
      end

      def variables(args) do
        Propagator.default_variables_impl(args)
      end

      defoverridable variables: 1, update: 2, new: 1, filter: 2
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
            ## We don't want propagator vars to keep domains, as propagator operates on store variables.
            ## Except when variables are fixed at the time propagator is created.
            ##
            ## Drop domain if variable is fixed, otherwise keep the fixed value
            fixed? = Domain.fixed?(domain)
            d = (fixed? && Domain.min(domain)) || nil

            arg
            |> Map.put(:fixed?, fixed?)
            |> Map.put(:domain, d)

          const ->
            const
        end)
    }
  end

  def update(%{mod: mod} = propagator, changes) do
    try do
      mod.update(propagator, changes)
    catch
      :fail ->
        :fail
    end
  end

  def filter(%{mod: mod, args: args} = propagator, opts \\ []) do
    PropagatorVariable.reset_variable_ops()
    store = Keyword.get(opts, :store)
    state = propagator[:state]
    ConstraintStore.set_store(store)

    try do
      mod.filter(args, state)
    catch
      :fail ->
        :fail
    else
      :fail ->
        :fail

      :stable ->
        :stable

      result ->
        get_filter_changes(result)
    end
  end

  def find_variable(args, var_id) do
    Enum.find(args, fn arg -> Interface.id(arg) == var_id end)
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
  end

  defp get_filter_changes(result) do
    get_filter_changes(result != :passive)
  end

  def bind_to_variables(propagator, indexed_variables) do
    bound_args =
      propagator.args
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
end
