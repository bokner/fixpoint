defmodule CPSolver.Solution.Handler do
  @callback handle(solution :: %{reference() => number() | boolean()}) :: any()
end

defmodule CPSolver.Solution.DefaultHandler do
  @behaviour CPSolver.Solution.Handler

  require Logger
  @impl true
  def handle(solution) do
    Logger.info("Solution found")
    Enum.each(solution, fn {var_id, value} -> Logger.info("#{inspect var_id} <- #{inspect value}") end)
  end
end
