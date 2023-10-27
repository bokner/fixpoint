defmodule CPSolver.Shared do
  def init_shared_data(solver_pid \\ self()) do
    %{
      solver: solver_pid,
      statistics:
        :ets.new(__MODULE__, [:set, :public, read_concurrency: true, write_concurrency: false])
        |> tap(fn stats_ref -> :ets.insert(stats_ref, {:stats, 1, 0, 0, 1}) end),
      solutions:
        :ets.new(__MODULE__, [:set, :public, read_concurrency: true, write_concurrency: true]),
      active_nodes:
        :ets.new(__MODULE__, [:set, :public, read_concurrency: true, write_concurrency: false])
    }
  end

  @active_node_count_pos 2
  @failure_count_pos 3
  @solution_count_pos 4
  @node_count_pos 5

  def add_active_spaces(%{statistics: stats_table} = _solver, spaces) do
    incr = length(spaces)
    update_stats_counters(stats_table, [{@active_node_count_pos, incr}, {@node_count_pos, incr}])
  end

  def remove_space(%{statistics: stats_table}, _space, reason) do
    update_stats_counters(stats_table, [{@active_node_count_pos, -1} | update_stats_ops(reason)])
  end

  defp update_stats_ops(:failure) do
    [{@failure_count_pos, 1}]
  end

  defp update_stats_ops(:solved) do
    [{@solution_count_pos, 1}]
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

  def add_failure(%{statistics: stats_table} = _solver) do
    update_stats_counters(stats_table, [{@failure_count_pos, 1}])
  end

  def add_solution(%{statistics: stats_table, solutions: solution_table} = _solver, solution) do
    update_stats_counters(stats_table, [{@solution_count_pos, 1}])
    :ets.insert(solution_table, {make_ref(), solution})
  end
end
