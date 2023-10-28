defmodule CPSolver do
  @moduledoc """
  Solver API.
  """

  alias CPSolver.Space
  alias CPSolver.Constraint
  alias CPSolver.Solution

  alias CPSolver.Shared

  use GenServer

  require Logger

  @doc """

  """
  @spec solve(Model.t(), Keyword.t()) :: any()
  def solve(model, opts \\ []) do
    shared_data = Shared.init_shared_data()
    {:ok, solver} = GenServer.start(CPSolver, [model, Keyword.put(opts, :shared, shared_data)])
    {:ok, Map.put(shared_data, :solver_pid, solver)}
  end

  def statistics(solver) when is_pid(solver) do
    GenServer.call(solver, :get_stats)
  end

  def statistics(solver) when is_map(solver) do
    Shared.statistics(solver)
  end

  def solutions(solver) when is_pid(solver) do
    GenServer.call(solver, :get_solutions)
  end

  def solutions(solver) when is_map(solver) do
    Shared.solutions(solver)
  end

  def get_state(solver) when is_pid(solver) do
    :sys.get_state(solver)
  end

  def get_state(solver) when is_map(solver) do
    get_state(solver.solver_pid)
  end

  ## GenServer callbacks

  @impl true
  def init([%{constraints: constraints, variables: variables} = _model, solver_opts]) do
    propagators =
      Enum.reduce(constraints, [], fn constraint, acc ->
        acc ++ Constraint.constraint_to_propagators(constraint)
      end)

    stop_on = Keyword.get(solver_opts, :stop_on)
    ## Some data (stats, solutions, possibly more - TBD) has to be shared between spaces
    shared = Keyword.get(solver_opts, :shared)

    {:ok,
     %{
       space: nil,
       variables: variables,
       propagators: propagators,
       shared: shared,
       stop_on: stop_on,
       solver_opts: solver_opts
     }, {:continue, :solve}}
  end

  @impl true
  def handle_continue(
        :solve,
        %{
          variables: variables,
          propagators: propagators,
          solver_opts: solver_opts,
          shared: shared
        } = state
      ) do
    solution_handler_fun =
      solver_opts
      |> Keyword.get(:solution_handler, Solution.default_handler())
      |> Solution.solution_handler(variables)

    {:ok, top_space} =
      Space.create(
        variables,
        propagators,
        solver_opts
        |> Keyword.put(:solver_data, shared)
        |> Keyword.put(:solution_handler, solution_handler_fun)
      )

    {:noreply, Map.put(state, :space, top_space)}
  end

  @impl true
  def handle_info(event, state) do
    {:noreply, handle_event(event, state)}
  end

  def handle_event(_event, state) do
    state
  end
end
