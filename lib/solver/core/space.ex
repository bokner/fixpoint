defmodule CPSolver.Space do
  @moduledoc """
  Computation space.
  The concept is taken from Chapter 12, "Concepts, Techniques, and Models
  of Computer Programming" by Peter Van Roy and Seif Haridi.
  """

  alias CPSolver.Utils
  alias __MODULE__, as: Space
  alias CPSolver.ConstraintStore, as: Store
  alias CPSolver.Propagator, as: Propagator
  alias CPSolver.Solution, as: Solution
  alias CPSolver.IntVariable, as: Variable

  require Logger

  @behaviour :gen_statem

  defstruct id: nil,
            parent: nil,
            keep_alive: false,
            variables: [],
            propagator_threads: %{},
            store: Store.default_store(),
            space: nil,
            solver: nil,
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
      :gen_statem.start(
        __MODULE__,
        [
          variables: variables,
          propagators: propagators,
          # Inject solver, if wasn't passed in opts
          space_opts: inject_solver(space_opts)
        ],
        gen_statem_opts
      )
  end

  defp inject_solver(space_opts) do
    Keyword.put_new(space_opts, :solver, self())
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
    space_id = make_ref()
    space_opts = Keyword.merge(default_space_opts(), Keyword.get(args, :space_opts, []))
    store_impl = Keyword.get(space_opts, :store)
    parent = Keyword.get(space_opts, :parent)
    keep_alive = Keyword.get(space_opts, :keep_alive, false)

    solution_handler = Keyword.get(space_opts, :solution_handler)
    search_strategy = Keyword.get(space_opts, :search)
    solver = Keyword.get(space_opts, :solver)
    ## Subscribe solver to space events
    Utils.subscribe(solver, {:space, space_id})
    {:ok, space_variables} = store_impl.create(self(), variables)

    space_data = %Space{
      id: space_id,
      parent: parent,
      keep_alive: keep_alive,
      variables: space_variables,
      store: store_impl,
      opts: space_opts,
      solution_handler: solution_handler,
      search: search_strategy
    }

    {:ok, :start_propagation, space_data, [{:next_event, :internal, {:propagate, propagators}}]}
  end

  @impl true
  def callback_mode() do
    [:state_functions, :state_enter]
  end

  ## Callbacks
  def start_propagation(:enter, :start_propagation, data) do
    {:keep_state, data}
  end

  def start_propagation(:internal, {:propagate, propagators}, data) do
    propagator_threads = start_propagation(propagators)
    {:next_state, :propagating, Map.put(data, :propagator_threads, propagator_threads)}
  end

  def propagating(:enter, :start_propagation, _data) do
    :keep_state_and_data
  end

  def propagating(:info, {:stable, propagator_thread}, data) do
    updated_data = set_propagator_stable(data, propagator_thread, true)

    if stable?(updated_data) do
      {:next_state, :stable, updated_data}
    else
      {:keep_state, updated_data}
    end
  end

  def propagating(:info, {:running, propagator_thread}, data) do
    Logger.debug("Running propagator #{inspect(propagator_thread)}")
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
    shutdown(data, :solved)
  end

  def failed(:enter, :propagating, data) do
    handle_failure(data)
    shutdown(data, :failure)
  end

  def solved(:enter, :propagating, data) do
    handle_solved(data)
    shutdown(data, :solved)
  end

  def stable(:enter, :propagating, data) do
    handle_stable(data)

    shutdown(
      data
      |> distribute()
      |> Enum.map(fn child_data ->
        {:ok, child_space} =
          create(
            child_data.variables,
            child_data.propagators,
            Keyword.put(data.opts, :parent, data.id)
          )

        child_space
      end)
      |> tap(fn new_nodes ->
        publish(data, {:nodes, new_nodes})
      end)
      |> then(fn children -> Map.put(data, :children, children) end),
      :distribute
    )
  end

  defp dispose(
         %{variables: variables, propagator_threads: threads, space: space, store: store} = _data
       ) do
    Enum.each(variables, fn var -> store.dispose(space, var) end)
    Enum.each(threads, fn {id, thread} -> Propagator.dispose(thread) end)
  end

  defp start_propagation(propagators) do
    Enum.reduce(propagators, Map.new(), fn p, acc ->
      propagator_id = make_ref()
      {:ok, thread} = Propagator.create_thread(self(), p, id: propagator_id)
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

  defp handle_failure(data) do
    Logger.debug("The space has failed")
    publish(data, :failure)
  end

  defp handle_solved(%{solution_handler: solution_handler} = data) do
    data
    |> solution()
    |> tap(fn solution -> publish(data, {:solution, solution}) end)
    |> Solution.run_handler(solution_handler)
  end

  defp handle_stable(data) do
    Logger.debug("Space #{inspect(data.id)} is stable")
  end

  def distribute(
        %{
          variables: variables,
          propagator_threads: threads,
          store: store_impl,
          search: search_strategy,
          space: space
        } = _data
      ) do
    variable_domains =
      Map.new(
        variables,
        fn v -> {v.id, store_impl.domain(space, v)} end
      )

    var_to_branch_on = search_strategy.select_variable(variables)
    var_domain = Map.get(variable_domains, var_to_branch_on.id)
    domain_partitions = search_strategy.partition(var_domain)

    Enum.map(domain_partitions, fn partition ->
      variable_copies =
        Map.new(variable_domains, fn {var_id, domain} ->
          {var_id,
           if var_id == var_to_branch_on.id do
             Variable.new(partition)
           else
             Variable.new(domain)
           end}
        end)

      propagator_copies =
        Enum.map(threads, fn {_ref, thread} ->
          {propagator_mod, args} = thread.propagator
          ## Replace variables in args to their copies
          {propagator_mod,
           Enum.map(args, fn
             %CPSolver.Variable{id: id} = _arg ->
               Map.get(variable_copies, id)

             const ->
               const
           end)}
        end)

      %{variables: Map.values(variable_copies), propagators: propagator_copies}
    end)
  end

  defp publish(data, message) do
    Utils.publish({:space, data.id}, message)
  end

  defp shutdown(%{keep_alive: keep_alive} = data, _reason) do
    publish(data, {:shutdown_space, data.space})

    if !keep_alive do
      dispose(data)
      {:stop, :normal, data}
    else
      :keep_state_and_data
    end
  end
end
