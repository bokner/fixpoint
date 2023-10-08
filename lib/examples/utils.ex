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
        |> then(fn sol -> solution_checker_fun.(sol) |> tap(fn res -> handle_checked(res) end) end)
    after
      timeout ->
        handle_timeout()
    end
    |> tap(fn _ -> flush_solutions() end)
  end

  def wait_for_solutions(0, _timeout, _solution_checker_fun) do
    :ok
  end

  def wait_for_solutions(num, timeout, solution_checker_fun) do
    case wait_for_solution(timeout, solution_checker_fun) do
      {:error, :timeout} ->
        {:error, :timeout}

      true ->
        wait_for_solutions(num - 1, timeout, solution_checker_fun)
    end
  end

  defp handle_timeout() do
    Logger.error("Timed out :-(")
    {:error, :timeout}
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
