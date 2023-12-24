defmodule CPSolver.Shared do
  alias CPSolver.Objective
  alias CPSolver.Variable.Interface

  def init_shared_data(max_space_threads: max_space_threads) do
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
      space_thread_counter: init_space_thread_counter(max_space_threads),
      times: init_times()
    }
  end

  def complete?(%{complete_flag: complete_flag} = _solver) do
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

  defp get_times(%{times: time_ref} = _solver) do
    {_start_time, _end_time} = :persistent_term.get(time_ref)
  end

  defp set_end_time(%{times: ref} = solver) do
    {start_time, _end_time} = get_times(solver)
    :persistent_term.put(ref, {start_time, :erlang.monotonic_time()})
  end

  ## First element is a thread counter, 2nd is the max number of
  ## space processes allowed to run simultaneously.
  defp init_space_thread_counter(max_space_threads) do
    ref = :counters.new(2, [:atomics])
    :counters.put(ref, 1, 0)
    :counters.put(ref, 2, max_space_threads)
    ref
  end

  def get_space_thread_counter(%{space_thread_counter: counter_ref} = _shared) do
    :counters.get(counter_ref, 1)
  end

  def checkout_space_thread(%{space_thread_counter: counter_ref} = _shared) do
    if :counters.get(counter_ref, 1) < :counters.get(counter_ref, 2) do
      :counters.add(counter_ref, 1, 1)
      true
    end
  end

  def checkin_space_thread(%{space_thread_counter: counter_ref} = _shared) do
    :counters.get(counter_ref, 1) > 0 && :counters.sub(counter_ref, 1, 1)
  end

  @active_node_count_pos 2
  @failure_count_pos 3
  @solution_count_pos 4
  @node_count_pos 5

  def add_active_spaces(
        %{statistics: stats_table, active_nodes: active_nodes_table} = _solver,
        spaces
      ) do
    try do
      incr = length(spaces)

      update_stats_counters(stats_table, [{@active_node_count_pos, incr}, {@node_count_pos, incr}])

      Enum.each(spaces, fn n -> :ets.insert(active_nodes_table, {n, n}) end)
    rescue
      _e -> :ok
    end
  end

  def remove_space(
        %{statistics: stats_table, active_nodes: active_nodes_table} = solver,
        space,
        reason
      ) do
    try do
      update_stats_counters(stats_table, [
        {@active_node_count_pos, -1} | update_stats_ops(reason)
      ])

      :ets.delete(active_nodes_table, space)
      ## The solving is done when there is no more active nodes
      :ets.info(active_nodes_table, :size) == 0 && set_complete(solver)
    rescue
      _e -> :ok
    end
  end

  def cleanup(
        %{solver_pid: solver_pid, complete_flag: complete_flag, objective: objective} = solver
      ) do
    Enum.each([:solutions, :statistics, :active_nodes], fn item ->
      Map.get(solver, item) |> :ets.delete()
    end)

    Process.alive?(solver_pid) && GenServer.stop(solver_pid)
    :persistent_term.erase(complete_flag)
    objective && Objective.reset_bound_handle(objective)
  end

  def stop_spaces(solver) do
    Enum.each(active_nodes(solver), fn space ->
      Process.alive?(space) && Process.exit(space, :normal)
    end)
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
    :ets.update_counter(stats_table, :stats, update_ops)
  end

  def statistics(solver) do
    [{:stats, active_node_count, failure_count, solution_count, node_count}] =
      :ets.lookup(solver.statistics, :stats)

    %{
      active_node_count: active_node_count,
      failure_count: failure_count,
      solution_count: solution_count,
      node_count: node_count,
      elapsed_time: elapsed_time(solver)
    }
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

  def objective_value(%{objective: objective_record} = _solver) do
    Objective.get_objective_value(objective_record)
  end

  def active_nodes(%{active_nodes: active_nodes_table} = _solver) do
    try do
      :ets.tab2list(active_nodes_table) |> Enum.map(fn {_k, n} -> n end)
    rescue
      _e -> []
    end
  end

  def add_failure(%{statistics: stats_table} = _solver) do
    update_stats_counters(stats_table, [{@failure_count_pos, 1}])
  end

  def add_solution(
        solution,
        %{solutions: solution_table, statistics: stats_table, objective: objective_rec} = _solver
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

  defp objective_value_from_solution(solution, %{variable: objective_variable} = _objective_rec) do
    obj_var = Interface.variable(objective_variable)

    Enum.find_value(solution, fn {var_name, value} ->
      var_name == obj_var.name && Interface.map(objective_variable, value)
    end)
  end
end
