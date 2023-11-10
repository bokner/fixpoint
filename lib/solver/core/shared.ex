defmodule CPSolver.Shared do
  def init_shared_data(solver_pid \\ self()) do
    %{
      caller: self(),
      sync_mode: false,
      solver_pid: solver_pid,
      statistics:
        :ets.new(__MODULE__, [:set, :public, read_concurrency: true, write_concurrency: false])
        |> tap(fn stats_ref -> :ets.insert(stats_ref, {:stats, 0, 0, 0, 0}) end),
      solutions:
        :ets.new(__MODULE__, [:set, :public, read_concurrency: true, write_concurrency: true]),
      active_nodes:
        :ets.new(__MODULE__, [:set, :public, read_concurrency: true, write_concurrency: false]),
      complete_flag: init_complete_flag()
    }
  end

  def complete?(%{complete_flag: complete_flag} = _solver) do
    :persistent_term.get(complete_flag)
  end

  def set_complete(%{complete_flag: complete_flag, caller: caller, sync_mode: sync?} = _solver) do
    :persistent_term.put(complete_flag, true)
    |> tap(fn _ -> sync? && send(caller, {:solver_completed, complete_flag}) end)
  end

  defp init_complete_flag() do
    make_ref()
    |> tap(fn ref -> :persistent_term.put(ref, false) end)
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

  def cleanup(%{solver_pid: solver_pid, complete_flag: complete_flag} = solver) do
    Enum.each(active_nodes(solver), fn space ->
      Process.alive?(space) && Process.exit(space, :normal)
    end)

    Enum.each([:solutions, :statistics, :active_nodes], fn item ->
      Map.get(solver, item) |> :ets.delete()
    end)

    Process.alive?(solver_pid) && GenServer.stop(solver_pid)
    :persistent_term.erase(complete_flag)
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
      node_count: node_count
    }
  end

  def solutions(%{solutions: solution_table} = _solver) do
    solution_table
    |> :ets.tab2list()
    |> Enum.map(fn {_ref, solution} ->
      Enum.map(solution, fn {_var, value} ->
        value
      end)
    end)
  end

  def active_nodes(%{active_nodes: active_nodes_table} = _solver) do
    :ets.tab2list(active_nodes_table) |> Enum.map(fn {_k, n} -> n end)
  end

  def add_failure(%{statistics: stats_table} = _solver) do
    update_stats_counters(stats_table, [{@failure_count_pos, 1}])
  end

  def add_solution(%{solutions: solution_table, statistics: stats_table} = _solver, solution) do
    update_stats_counters(stats_table, [{@solution_count_pos, 1}])
    :ets.insert(solution_table, {make_ref(), solution})
  end
end
