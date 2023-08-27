defmodule CPSolver do
  @moduledoc """
  Solver API.
  """

  alias CPSolver.Space
  use GenServer

  require Logger

  @doc """

  """
  @spec solve(module(), Keyword.t()) :: any()
  def solve(model, opts \\ []) do
    {:ok, _solver} = GenServer.start_link(CPSolver, [model, opts])
  end

  ## GenServer callbacks

  @impl true
  def init([model, solver_opts]) do
    propagators =
      Enum.reduce(model.constraints, [], fn constraint, acc ->
        acc ++ constraint_to_propagators(constraint)
      end)

    {:ok, top_space} =
      Space.create(model.variables, propagators, Keyword.put(solver_opts, :solver, self()))

    {:ok, %{space: top_space, solver_opts: solver_opts}}
  end

  defp constraint_to_propagators(constraint) do
    [constraint_mod | args] = Tuple.to_list(constraint)
    constraint_mod.propagators(args)
  end

  @impl true
  def handle_info(event, state) do
    {:noreply, handle_event(event, state)}
  end

  defp handle_event({:solution, solution}, state) do
    Logger.debug("Solver got a new solution")
    state
  end
end
