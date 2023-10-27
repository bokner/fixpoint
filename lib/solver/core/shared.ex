defmodule CPSolver.Shared do
  def init_shared_data(solver_pid \\ self()) do
    %{
      solver: solver_pid,
      statistics:
        :ets.new(__MODULE__, [:set, :public, read_concurrency: true, write_concurrency: false]),
      solutions:
        :ets.new(__MODULE__, [:set, :public, read_concurrency: true, write_concurrency: true]),
      active_nodes:
        :ets.new(__MODULE__, [:set, :public, read_concurrency: true, write_concurrency: false])
    }
  end

  @active_node_count_pos 0
  @failure_count_pos 1
  @solution_count_pos 2
  @node_count_pos 3
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

  def add_failure(solver) do
  end

  def add_solution(solver, solution) do
  end
end
