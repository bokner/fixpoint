defmodule CPSolver.Examples.Utils do
  require Logger

  def notify_client_handler() do
    client = self()
    fn solution -> send(client, {:solution, solution}) end
  end

  def wait_for_solution(timeout, solution_checker_fun) do
    receive do
      {:solution, solution} ->
        solution
        |> Enum.map(fn {_ref, s} -> s end)
        |> then(fn sol -> handle_checked(solution_checker_fun.(sol)) end)
    after
      timeout ->
        handle_timeout()
    end
    |> tap(fn _ -> flush_solutions() end)
  end

  defp handle_timeout() do
    Logger.info("Timed out :-(")
  end

  defp handle_checked(solution_checked?) do
    (solution_checked? && Logger.notice("Solution checked!")) || Logger.error("Wrong solution!")
  end

  def flush_solutions() do
    receive do
      {:solution, _} -> flush_solutions()
    after
      0 -> :ok
    end
  end
end
