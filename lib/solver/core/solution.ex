defmodule CPSolver.Solution do
  @callback handle(solution :: %{reference() => number() | boolean()}) :: any()
  def default_handler() do
    CPSolver.Solution.DefaultHandler
  end

  def run_handler(solution, handler) when is_atom(handler) do
    handler.handle(solution)
  end

  def run_handler(solution, handler) when is_function(handler) do
    handler.(solution)
  end

  def reconcile(solution, variables) do
    ## We want to present a solution (which is var_name => value map) in order of initial variable names.
    solution
    |> Map.to_list()
    |> Enum.sort_by(fn {var_name, _val} ->
      Enum.find_index(
        variables,
        fn var ->
          var.name == var_name
        end
      )
    end)
  end
end

defmodule CPSolver.Solution.DefaultHandler do
  @behaviour CPSolver.Solution

  require Logger
  @impl true
  def handle(solution) do
    Logger.debug("Solution found")

    Enum.each(solution, fn {var_id, value} ->
      Logger.debug("#{inspect(var_id)} <- #{inspect(value)}")
    end)
  end
end
