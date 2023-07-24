defmodule CPSolver do
  @moduledoc """
  Solver API.
  """

  alias CPSolver.Space
  use GenServer

  require Logger

  @doc """

  """
  @spec solve(module(), module(), Keyword.t()) :: any()
  def solve(model, search, opts \\ []) do
    {:ok, solver} = make_solver(model, search, opts)
    solve(solver)
  end

  def make_solver(model, search, opts \\ []) do
    {:ok, _solver} = GenServer.start_link(CPSolver, [model, search, opts])
  end

  def solve(solver) do
    send(solver, :start)
  end

  ## GenServer callbacks

  @impl true
  def init([model, search, solver_opts]) do
    top_space = Space.create(model.variables, model.constraints, search, solver_opts)
    {:ok, %{space: top_space, solver_opts: solver_opts}}
  end

  @impl true
  def handle_info(event, state) do
    {:noreply, handle_event(event, state)}
  end

  defp handle_event(event, state) do
    Logger.debug("Solver process event: #{inspect(event)}")
    state
  end
end
