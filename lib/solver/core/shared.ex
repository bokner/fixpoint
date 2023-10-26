defmodule CPSolver.Shared do
  def init_shared_data() do
    %{
      statistics:
        :ets.new(__MODULE__, [:set, :public, read_concurrency: true, write_concurrency: false]),
      solutions:
        :ets.new(__MODULE__, [:set, :public, read_concurrency: true, write_concurrency: true]),
      active_nodes:
        :ets.new(__MODULE__, [:set, :public, read_concurrency: true, write_concurrency: false])
    }
  end

  def add_active_spaces(solver, spaces) do
  end

  def remove_space(solver, space, reason) do
  end

  def add_failure(solver) do
  end

  def add_solution(solver, solution) do
  end
end
