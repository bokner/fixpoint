defmodule CPSolver.Space do
  @moduledoc """
  Computation space.
  The concept is taken from Chapter 12, "Concepts, Techniques, and Models
  of Computer Programming" by Peter Van Roy and Seif Haridi.
  """

  alias __MODULE__, as: Space
  alias CPSolver.ConstraintStore, as: Store
  alias CPSolver.Propagator, as: Propagator
  alias CPSolver.Solution, as: Solution
  alias CPSolver.IntVariable, as: Variable

  require Logger

  @behaviour :gen_statem

  defstruct variables: [],
            propagators: [],
            propagator_threads: [],
            store: Store.default_store(),
            space: nil,
            solution_handler: nil,
            search: nil,
            opts: []

  defp default_space_opts() do
    [
      store: Store.default_store(),
      solution_handler: Solution.default_handler(),
      search: CPSolver.Search.Strategy.default_strategy()
    ]
  end

  def create(variables, propagators, space_opts \\ [], gen_statem_opts \\ []) do
    {:ok, _space} =
      :gen_statem.start_link(
        __MODULE__,
        [variables: variables, propagators: propagators, space_opts: space_opts],
        gen_statem_opts
      )
  end

  def get_state_and_data(space) do
    {_state, _data} = :sys.get_state(space)
  end

  def solution(%{variables: variables, space: space, store: store} = _data) do
    Enum.reduce(variables, Map.new(), fn var, acc ->
      Map.put(acc, var.id, store.get(space, var, :min))
    end)
  end

  @impl true
  def init(args) do
    variables = Keyword.get(args, :variables)
    propagators = Keyword.get(args, :propagators)

    space = self()

    space_opts = Keyword.merge(default_space_opts(), Keyword.get(args, :space_opts, []))
    store_impl = Keyword.get(space_opts, :store)

    solution_handler = Keyword.get(space_opts, :solution_handler)
    search_strategy = Keyword.get(space_opts, :search)
    {:ok, space_variables} = store_impl.create(space, variables)

    space_data = %Space{
      variables: space_variables,
      propagators: propagators,
      store: store_impl,
      space: space,
      opts: space_opts,
      solution_handler: solution_handler,
      search: search_strategy
    }

    {:ok, :start_propagation, space_data, [{:next_event, :internal, :propagate}]}
  end

  @impl true
  def callback_mode() do
    [:state_functions, :state_enter]
  end

  ## Callbacks
  def start_propagation(:enter, :start_propagation, data) do
    {:keep_state, data}
  end

  def start_propagation(:internal, :propagate, data) do
    propagator_threads = start_propagation(data)
    {:next_state, :propagating, Map.put(data, :propagator_threads, propagator_threads)}
  end

  def propagating(:enter, :start_propagation, _data) do
    Logger.debug("Propagation in progress")
    :keep_state_and_data
  end

  def propagating(:info, {:stable, propagator_thread}, data) do
    Logger.debug("Stable propagator")
    updated_data = set_propagator_stable(data, propagator_thread, true)

    if stable?(updated_data) do
      {:next_state, :stable, updated_data}
    else
      {:keep_state, updated_data}
    end
  end

  def propagating(:info, {:running, propagator_thread}, data) do
    Logger.debug("Running propagator")
    {:keep_state, set_propagator_stable(data, propagator_thread, false)}
  end

  def propagating(:info, {:entailed, propagator_thread}, data) do
    Logger.debug("Entailed propagator #{inspect(propagator_thread)}")
    updated_data = update_entailed(data, propagator_thread)

    if solved?(updated_data) do
      {:next_state, :solved, updated_data}
    else
      {:keep_state, updated_data}
    end
  end

  def propagating(:info, {:failed, _propagator_thread}, data) do
    {:next_state, :failed, data}
  end

  def propagating(:info, :solved, data) do
    Logger.debug("The space has been solved")
    {:next_state, :solved, data}
  end

  def failed(:enter, :propagating, data) do
    handle_failure(data)
    :keep_state_and_data
  end

  def solved(:enter, :propagating, data) do
    handle_solved(data)
    :keep_state_and_data
  end

  def stable(:enter, :propagating, data) do
    handle_stable(data)
    {:keep_state, distribute(data)}
  end

  defp start_propagation(%{propagators: propagators, space: space} = _space_state) do
    Logger.debug("Start propagation")

    Enum.reduce(propagators, Map.new(), fn p, acc ->
      propagator_id = make_ref()
      {:ok, thread} = Propagator.create_thread(space, p, id: propagator_id)
      Map.put(acc, propagator_id, %{thread: thread, propagator: p, stable: false})
    end)
  end

  defp stable?(%{propagator_threads: threads} = _data) do
    Enum.all?(threads, fn {_id, thread} -> thread.stable end)
  end

  defp set_propagator_stable(%{propagator_threads: threads} = data, propagator_id, stable?) do
    %{
      data
      | propagator_threads:
          Map.update!(threads, propagator_id, fn content -> Map.put(content, :stable, stable?) end)
    }
  end

  def update_entailed(%{propagator_threads: threads} = data, propagator_thread) do
    Map.put(data, :propagator_threads, Map.delete(threads, propagator_thread))
  end

  defp solved?(data) do
    map_size(data.propagator_threads) == 0
  end

  defp handle_failure(_data) do
    Logger.debug("The space has failed")
  end

  defp handle_solved(%{solution_handler: solution_handler} = data) do
    data
    |> solution()
    |> Solution.run_handler(solution_handler)
  end

  defp handle_stable(data) do
    Logger.debug("Space #{inspect(data.space)} is stable")
  end

  defp distribute(data) do
    Logger.debug("Distributing the space...")
    :todo

    # copy(data)
  end

  def copy(space) when is_pid(space) do
    {_state, data} = get_state_and_data(space)
    copy(data)
  end

  def copy(
        %{
          variables: variables,
          propagator_threads: threads,
          store: store_impl,
          search: search_strategy,
          space: space,
          opts: opts
        } =
          _data
      ) do
    variable_copies =
      Map.new(
        variables,
        fn v -> {v.id, store_impl.domain(space, v) |> then(fn d -> {Variable.new(d), d} end)} end
      )

    propagator_copies =
      Enum.map(threads, fn {_ref, thread} ->
        {propagator_mod, args} = thread.propagator
        ## Replace variables in args to their copies
        {propagator_mod,
         Enum.map(args, fn
           %CPSolver.Variable{id: id} = _arg ->
             {var, _domain} = Map.get(variable_copies, id)
             var

           const ->
             const
         end)}
      end)

    variable_to_branch_on = search_strategy.select_variable(variables)
    {new_var, domain} = Map.get(variable_copies, variable_to_branch_on.id)
    value_branching = search_strategy.partition(domain)

    new_variables = Map.values(variable_copies) |> Enum.map(fn {var, _domain} -> var end)
    create(new_variables, propagator_copies, opts)
  end
end
