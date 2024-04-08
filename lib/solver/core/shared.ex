defmodule CPSolver.Shared do
  alias CPSolver.Objective
  alias CPSolver.Variable.Interface
  alias CPSolver.Distributed

  def init_shared_data(opts) do
    distributed = Keyword.get(opts, :distributed, false)
    max_space_threads = Keyword.get(opts, :max_space_threads)

    %{
      caller: self(),
      sync_mode: false,
      solver_pid: self(),
      statistics:
        :ets.new(__MODULE__, [:set, :public, read_concurrency: true, write_concurrency: false])
        |> tap(fn stats_ref -> :ets.insert(stats_ref, {:stats, 0, 0, 0, 0}) end),
      solutions:
        :ets.new(__MODULE__, [:set, :public, read_concurrency: true, write_concurrency: true]),
      active_nodes:
        :ets.new(__MODULE__, [:set, :public, read_concurrency: true, write_concurrency: false]),
      complete_flag: init_complete_flag(),
      space_thread_counters: init_space_thread_counters(max_space_threads),
      times: init_times(),
      distributed: distributed
    }
  end

  def complete?(solver) do
    (on_primary_node?(solver) &&
       complete_impl(solver)) ||
      distributed_call(solver, :complete_impl)
  end

  def complete_impl(%{complete_flag: complete_flag} = _solver) do
    :persistent_term.get(complete_flag, true)
  end

  def set_complete(%{complete_flag: complete_flag, caller: caller, sync_mode: sync?} = solver) do
    :persistent_term.put(complete_flag, true)

    set_end_time(solver)
    |> tap(fn _ -> sync? && send(caller, {:solver_completed, complete_flag}) end)
    |> tap(fn _ -> CPSolver.stop_spaces(solver) end)
  end

  ## Elapsed time in microsecs
  def elapsed_time(solver) do
    {start_time, end_time} = get_times(solver)

    (((end_time && end_time) || :erlang.monotonic_time()) - start_time)
    |> div(1_000)
  end

  defp init_complete_flag() do
    make_ref()
    |> tap(fn ref -> :persistent_term.put(ref, false) end)
  end

  def init_times() do
    make_ref()
    |> tap(fn ref -> :persistent_term.put(ref, {:erlang.monotonic_time(), nil}) end)
  end

  def get_times(solver) do
    (on_primary_node?(solver) &&
       get_times_impl(solver)) ||
      distributed_call(solver, :get_times_impl)
  end

  def get_times_impl(%{times: time_ref} = _solver) do
    {_start_time, _end_time} = :persistent_term.get(time_ref)
  end

  def set_end_time(solver) do
    (on_primary_node?(solver) &&
       set_end_time_impl(solver)) ||
      distributed_call(solver, :get_times_impl)
  end

  def set_end_time_impl(%{times: ref} = solver) do
    {start_time, _end_time} = get_times(solver)
    :persistent_term.put(ref, {start_time, :erlang.monotonic_time()})
  end

  ## This is a map nodes => atomics
  ## The value is 2-element (:counters) array
  ## First element is a thread counter, 2nd is the max number of
  ## space processes allowed to run simultaneously on a given node.
  defp init_space_thread_counters(max_space_threads, nodes \\ [Node.self() | Node.list()]) do
    Map.new(nodes, fn node ->
      ref = :counters.new(2, [:atomics])
      :counters.put(ref, 1, 0)
      :counters.put(ref, 2, max_space_threads)
      {node, ref}
    end)
    |> then(fn node_thread_counters ->
      make_ref()
      |> tap(fn ref -> :persistent_term.put(ref, node_thread_counters) end)
    end)
  end

  def get_space_thread_counter(
        %{space_thread_counters: node_threads_ref} = _shared,
        node \\ Node.self()
      ) do
    counter_ref = :persistent_term.get(node_threads_ref) |> Map.get(node)
    :counters.get(counter_ref, 1)
  end

  def checkout_space_thread(solver, node \\ Node.self()) do
    (on_primary_node?(solver) &&
       checkout_space_thread_impl(solver, node)) ||
      distributed_call(solver, :checkout_space_thread_impl, [node])
  end

  def checkout_space_thread_impl(
        %{space_thread_counters: node_threads_ref} = _solver,
        node
      ) do
    counter_ref = :persistent_term.get(node_threads_ref) |> Map.get(node)

    if :counters.get(counter_ref, 1) < :counters.get(counter_ref, 2) do
      :counters.add(counter_ref, 1, 1)
      true
    end
  end

  def checkin_space_thread(solver) do
    (on_primary_node?(solver) &&
       checkin_space_thread_impl(solver)) ||
      distributed_call(solver, :checkin_space_thread_impl)
  end

  def checkin_space_thread_impl(
        %{space_thread_counters: node_threads_ref} = _solver,
        node \\ Node.self()
      ) do
    counter_ref = :persistent_term.get(node_threads_ref) |> Map.get(node)
    :counters.get(counter_ref, 1) > 0 && :counters.sub(counter_ref, 1, 1)
  end

  @active_node_count_pos 2
  @failure_count_pos 3
  @solution_count_pos 4
  @node_count_pos 5

  def on_primary_node?(%{solver_pid: solver_pid} = _solver) do
    Node.self() == node(solver_pid)
  end

  def increment_node_counts(solver) do
    (on_primary_node?(solver) &&
       increment_node_counts_impl(solver)) ||
      distributed_call(solver, :increment_node_counts_impl)
  end

  def increment_node_counts_impl(%{statistics: stats_table}) do
    update_stats_counters(stats_table, [{@active_node_count_pos, 1}, {@node_count_pos, 1}])
  end

  def add_active_spaces(
        solver,
        spaces
      ) do
    (on_primary_node?(solver) &&
       add_active_spaces_impl(solver, spaces)) ||
      distributed_call(solver, :add_active_spaces_impl, [spaces])
  end

  def add_active_spaces_impl(%{active_nodes: active_nodes_table} = _solver_state, spaces) do
    try do
      Enum.each(spaces, fn n -> :ets.insert(active_nodes_table, {n, n}) end)
    rescue
      _e -> :ok
    end
  end

  def remove_space(solver, space, reason) do
    (on_primary_node?(solver) &&
       remove_space_impl(solver, space, reason)) ||
      distributed_call(solver, :remove_space_impl, [space, reason])
  end

  def remove_space_impl(
        %{statistics: stats_table, active_nodes: active_nodes_table} = solver,
        space,
        reason
      ) do
    try do
      [active_node_count | _] =
        update_stats_counters(stats_table, [
          {@active_node_count_pos, -1, 0, 0} | update_stats_ops(reason)
        ])

      :ets.delete(active_nodes_table, space)
      ## The solving is done when there is no more active nodes
      active_node_count == 0 && set_complete(solver)
      :ok
    rescue
      _e -> :ok
    end
  end

  def cleanup(solver) do
    (on_primary_node?(solver) &&
       cleanup_impl(solver)) ||
      distributed_call(solver, :cleanup_impl)
  end

  def cleanup_impl(
        %{solver_pid: solver_pid, complete_flag: complete_flag, objective: objective} = solver
      ) do
    Enum.each([:solutions, :statistics, :active_nodes], fn item ->
      Map.get(solver, item) |> :ets.delete()
    end)

    Process.alive?(solver_pid) && GenServer.stop(solver_pid)
    :persistent_term.erase(complete_flag)
    reset_objective(objective)
    :ok
  end

  def stop_spaces(solver) do
    Enum.each(active_nodes(solver), fn space ->
      :erpc.cast(node(space), fn -> Process.alive?(space) && Process.exit(space, :normal) end)
    end)
  end

  def add_failure(solver) do
    (on_primary_node?(solver) &&
       add_failure_impl(solver)) ||
      distributed_call(solver, :add_failure_impl)
  end

  def add_failure_impl(%{statistics: stats_table} = _solver) do
    update_stats_counters(stats_table, [{@failure_count_pos, 1}])
  end

  def add_solution(solver, solution) do
    (on_primary_node?(solver) &&
       add_solution_impl(solver, solution)) ||
      distributed_call(solver, :add_solution_impl, [solution])
  end

  def add_solution_impl(
        %{solutions: solution_table, statistics: stats_table, objective: objective_rec} = _solver,
        solution
      ) do
    try do
      update_stats_counters(stats_table, [{@solution_count_pos, 1}])

      :ets.insert(
        solution_table,
        {make_ref(),
         %{
           solution: Enum.map(solution, fn {_var_id, value} -> value end),
           objective_value:
             objective_rec && objective_value_from_solution(solution, objective_rec)
         }}
      )
    rescue
      _e -> :ok
    end
  end

  defp update_stats_ops(:failure) do
    [{@failure_count_pos, 1}]
  end

  defp update_stats_ops(:solved) do
    []
  end

  defp update_stats_ops(_) do
    []
  end

  defp update_stats_counters(stats_table, update_ops) do
    try do
      :ets.update_counter(stats_table, :stats, update_ops)
    rescue
      _e -> []
    end
  end

  defp reset_objective(objective) do
    objective && Objective.reset_bound(objective)
  end

  def statistics(solver) do
    (on_primary_node?(solver) &&
       statistics_impl(solver)) ||
      distributed_call(solver, :statistics_impl)
  end

  def statistics_impl(solver) do
    try do
      [{:stats, active_node_count, failure_count, solution_count, node_count}] =
        :ets.lookup(solver.statistics, :stats)

      %{
        active_node_count: active_node_count,
        failure_count: failure_count,
        solution_count: solution_count,
        node_count: node_count,
        elapsed_time: elapsed_time(solver)
      }
    rescue
      _e ->
        %{}
    end
  end

  def solutions(%{solutions: solution_table} = _solver) do
    try do
      solution_table
      |> :ets.tab2list()
      ## Sort solutions by the objective value (the best solution is placed last)
      |> Enum.sort_by(
        fn {_ref, %{objective_value: objective_value}} ->
          objective_value
        end,
        :desc
      )
      |> Enum.map(fn {_ref, %{solution: solution}} -> solution end)
    rescue
      _e -> []
    end
  end

  def objective_value(%{objective: nil} = _solver) do
    nil
  end

  def objective_value(solver) do
    (on_primary_node?(solver) &&
       objective_value_impl(solver)) ||
      distributed_call(solver, :objective_value_impl)
  end

  def objective_value_impl(%{objective: objective_record} = _solver) do
    Objective.get_objective_value(objective_record)
  end

  def active_nodes(%{active_nodes: active_nodes_table} = _solver) do
    try do
      :ets.tab2list(active_nodes_table) |> Enum.map(fn {_k, n} -> n end)
    rescue
      _e -> []
    end
  end

  defp objective_value_from_solution(solution, %{variable: objective_variable} = _objective_rec) do
    obj_var = Interface.variable(objective_variable)

    Enum.find_value(solution, fn {var_name, value} ->
      var_name == obj_var.name && Interface.map(objective_variable, value)
    end)
  end

  defp distributed_call(%{solver_pid: solver_pid} = solver, function, args \\ []) do
    Distributed.call(node(solver_pid), solver, __MODULE__, function, args)
  end
end
