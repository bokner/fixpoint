defmodule CPSolver.Space do
  @moduledoc """
  Computation space.
  The concept is taken from Chapter 12, "Concepts, Techniques, and Models
  of Computer Programming" by Peter Van Roy and Seif Haridi.
  """

  alias CPSolver.Utils
  alias __MODULE__, as: Space
  alias CPSolver.ConstraintStore
  alias CPSolver.Propagator
  alias CPSolver.Propagator.Thread, as: PropagatorThread
  alias CPSolver.Solution, as: Solution
  alias CPSolver.IntVariable, as: Variable
  alias CPSolver.DefaultDomain, as: Domain
  alias CPSolver.Propagator.ConstraintGraph
  alias CPSolver.Utils

  alias CPSolver.Shared

  require Logger

  @behaviour :gen_statem

  defstruct id: nil,
            parent: nil,
            keep_alive: false,
            variables: [],
            propagators: [],
            constraint_graph: nil,
            propagator_threads: %{},
            store: nil,
            space: nil,
            solver_data: nil,
            solution_handler: nil,
            search: nil,
            opts: []

  defp default_space_opts() do
    [
      store: CPSolver.ConstraintStore.default_store(),
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
          space_opts: space_opts
        ],
        gen_statem_opts
      )
  end

  def stop(space) do
    Process.alive?(space) && :gen_statem.stop(space)
  end

  def get_state_and_data(space) do
    {_state, _data} = :sys.get_state(space)
  end

  def solution(%{variables: variables, store: store} = _data) do
    Enum.reduce_while(variables, Map.new(), fn var, acc ->
      case ConstraintStore.get(store, var, :min) do
        :fail -> {:halt, :fail}
        val -> {:cont, Map.put(acc, var.name, val)}
      end
    end)
  end

  @impl true
  def init(args) do
    variables = Keyword.get(args, :variables)
    space_id = make_ref()
    space_opts = Keyword.merge(default_space_opts(), Keyword.get(args, :space_opts, []))
    store_impl = Keyword.get(space_opts, :store)
    parent = Keyword.get(space_opts, :parent)
    keep_alive = Keyword.get(space_opts, :keep_alive, false)

    solution_handler = Keyword.get(space_opts, :solution_handler)
    search_strategy = Keyword.get(space_opts, :search)
    solver_data = Keyword.get(space_opts, :solver_data)

    propagators = Keyword.get(args, :propagators) |> Propagator.normalize()

    constraint_graph = create_constraint_graph(propagators)

    {:ok, space_variables, store} =
      ConstraintStore.create_store(variables,
        store_impl: store_impl,
        space: self(),
        constraint_graph: constraint_graph
      )

    space_data = %Space{
      id: space_id,
      parent: parent,
      keep_alive: keep_alive,
      variables: space_variables,
      propagators: propagators,
      constraint_graph: constraint_graph,
      store: store,
      solver_data: solver_data,
      opts: space_opts,
      solution_handler: solution_handler,
      search: search_strategy
    }

    {:ok, :start_propagation, space_data, [{:next_event, :internal, {:propagate, propagators}}]}
  end

  defp create_constraint_graph(propagators) do
    propagators
    |> ConstraintGraph.create()
    |> then(fn graph ->
      :ets.new(__MODULE__, [:set, :public, read_concurrency: true, write_concurrency: true])
      |> tap(fn table_id -> ConstraintGraph.update_graph(graph, table_id) end)

      # Temporary
      # graph
    end)
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
    propagator_threads = create_propagator_threads(propagators, data)
    {:next_state, :propagating, Map.put(data, :propagator_threads, propagator_threads)}
  end

  def propagating(:enter, :start_propagation, _data) do
    :keep_state_and_data
  end

  def propagating(:info, {:stable, propagator_thread}, data) do
    updated_data = update_scheduled(data, propagator_thread, false)

    if fixpoint?(updated_data) do
      {:next_state, :stable, updated_data}
    else
      {:keep_state, updated_data}
    end
  end

  def propagating(:info, {:entailed, propagator_thread}, data) do
    updated_data = update_entailed(data, propagator_thread)

    cond do
      solved?(updated_data) -> {:next_state, :solved, updated_data}
      fixpoint?(updated_data) -> {:next_state, :stable, updated_data}
      true -> {:keep_state, updated_data}
    end
  end

  def propagating(:info, {{domain_change, propagator_threads}, variable_id}, data) do
    updated_data =
      Enum.reduce(propagator_threads, data, fn p_ref, acc ->
        notify_propagator(acc, p_ref, {domain_change, variable_id})
      end)

    {:keep_state, updated_data}
  end

  def propagating(:info, {:fail, _variable_id}, data) do
    {:next_state, :failed, data}
  end

  def propagating(:info, :solved, data) do
    {:next_state, :solved, data}
  end

  @spec failed(any, any, any) :: :keep_state_and_data
  def failed(:enter, :propagating, data) do
    handle_failure(data)
  end

  def failed(kind, message, _data) do
    unexpected_message(:failed, kind, message)
  end

  def solved(:enter, :propagating, data) do
    handle_solved(data)
  end

  def solved(kind, message, _data) do
    unexpected_message(:solved, kind, message)
  end

  def stable(:enter, :propagating, data) do
    handle_stable(data)
  end

  def stable(kind, message, _data) do
    unexpected_message(:stable, kind, message)
  end

  defp unexpected_message(state, kind, message) do
    Logger.error(
      "Unexpected message in state #{inspect(state)}: #{inspect(kind)}: #{inspect(message)}"
    )

    :keep_state_and_data
  end

  defp create_propagator_threads(propagators, data) do
    Map.new(propagators, fn {propagator_id, p} ->
      {:ok, thread} =
        PropagatorThread.create_thread(self(), p,
          id: propagator_id,
          store: data.store
        )

      {propagator_id, %{thread: thread, propagator: p, scheduled_runs: 1}}
    end)
  end

  defp fixpoint?(%{propagator_threads: threads} = _data) do
    Enum.all?(threads, fn {_id, thread} -> thread.scheduled_runs == 0 end)
  end

  defp update_scheduled(
         %{propagator_threads: threads} = data,
         propagator_id,
         scheduled?,
         thread_action \\ nil
       ) do
    threads
    |> Map.get(propagator_id)
    |> then(fn
      nil ->
        data

      %{scheduled_runs: scheduled_runs} = thread_rec ->
        thread_action && thread_action.(thread_rec)
        inc_dec = (scheduled? && 1) || -1

        %{
          data
          | propagator_threads:
              Map.put(
                threads,
                propagator_id,
                Map.put(thread_rec, :scheduled_runs, scheduled_runs + inc_dec)
              )
        }
    end)
  end

  defp notify_propagator(data, propagator_id, domain_change_event) do
    update_scheduled(data, propagator_id, true, fn thread ->
      send(thread.thread, domain_change_event)
    end)
  end

  def update_entailed(
        %{propagator_threads: threads, constraint_graph: graph} = data,
        propagator_thread
      ) do
    Map.put(
      data,
      :propagator_threads,
      Map.delete(threads, propagator_thread)
    )
    |> tap(fn _data -> ConstraintGraph.remove_propagator(graph, propagator_thread) end)
  end

  defp solved?(data) do
    map_size(data.propagator_threads) == 0
  end

  defp handle_failure(data) do
    Shared.add_failure(data.solver_data)
    shutdown(data, :failure)
  end

  defp handle_solved(%{solution_handler: solution_handler} = data) do
    data
    |> solution()
    |> then(fn
      :fail ->
        handle_failure(data)

      solution ->
        Shared.add_solution(data.solver_data, solution)
        publish(data, {:solution, solution})
        Solution.run_handler(solution, solution_handler)
        shutdown(data, :solved)
    end)
  end

  defp handle_stable(data) do
    distribute(data)
  end

  def distribute(
        %{
          variables: variables
        } = data
      ) do
    {localized_vars, _all_fixed?} = Utils.localize_variables(variables)

    do_distribute(data, localized_vars)
  end

  def do_distribute(
        %{
          propagator_threads: threads,
          search: search_strategy
        } = data,
        variable_clones
      ) do
    case branching(variable_clones, search_strategy) do
      {:ok, {var_to_branch_on, domain_partitions}} ->
        Enum.map(domain_partitions, fn partition ->
          variable_copies =
            Map.new(variable_clones, fn %{id: clone_id} = clone ->
              if clone_id == var_to_branch_on.id do
                {clone_id, Variable.copy(clone) |> Map.put(:domain, Domain.new(partition))}
              else
                {clone_id, Variable.copy(clone)}
              end
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

          {:ok, child_space} =
            create(
              Map.values(variable_copies),
              propagator_copies,
              Keyword.put(data.opts, :parent, data.id)
            )

          child_space
        end)
        |> tap(fn new_nodes ->
          Shared.remove_space(data.solver_data, self(), :distribute)
          Shared.add_active_spaces(data.solver_data, new_nodes)
          publish(data, {:nodes, new_nodes})
        end)

        shutdown(data, :distribute)
    end
  end

  defp branching(variables, search_strategy) do
    case search_strategy.select_variable(variables) do
      {:ok, var_to_branch_on} ->
        var_domain = var_to_branch_on.domain

        case search_strategy.partition(var_domain) do
          :fail -> :fail
          {:ok, partitions} -> {:ok, {var_to_branch_on, partitions}}
        end

      error ->
        error
    end
  end

  defp publish(data, message) do
    send(data.solver_data.solver, message)
  end

  defp shutdown(%{keep_alive: keep_alive} = data, reason) do
    Shared.remove_space(data.solver_data, self(), reason)

    if !keep_alive do
      publish(data, {:shutdown_space, {self(), reason}})
      {:stop, :normal, data}
    else
      :keep_state_and_data
    end
  end

  @impl true
  def terminate(_reason, _current_state, data) do
    cleanup(data)
  end

  defp cleanup(%{propagator_threads: threads, store: store, variables: variables} = _data) do
    Enum.each(threads, fn {_ref, thread} -> PropagatorThread.dispose(thread) end)
    ConstraintStore.dispose(store, variables)
  end
end
