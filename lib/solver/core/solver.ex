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
    # :ets.tab2list(solver.shared.statistics)
    # statistics(solver.solver_pid)
    Shared.statistics(solver)
  end

  def solutions(solver) when is_pid(solver) do
    GenServer.call(solver, :get_solutions)
  end

  def solutions(solver) when is_map(solver) do
    # :ets.tab2list(solver.shared.statistics)
    # solutions(solver.solver_pid)
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
       solution_count: 0,
       failure_count: 0,
       node_count: 1,
       shared: Map.put(shared, :solver, self()),
       solutions: [],
       active_nodes: MapSet.new(),
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

  defp handle_event(
         {:solution, new_solution},
         %{solution_count: count, solutions: solutions, variables: variables, stop_on: stop_on} =
           state
       ) do
    if check_for_stop(stop_on, new_solution, state) do
      stop_spaces(state)
    else
      %{
        state
        | solution_count: count + 1,
          solutions: [Solution.reconcile(new_solution, variables) | solutions]
      }
    end
  end

  defp check_for_stop(nil, _solution, _data) do
    false
  end

  defp check_for_stop({:max_solutions, max}, _solution, data) do
    max == data.solution_count
  end

  defp check_for_stop(condition, solution, data) when is_function(condition, 2) do
    condition.(solution, data)
  end

  defp stop_spaces(%{active_nodes: spaces} = data) do
    Enum.each(spaces, fn s -> Process.alive?(s) && Process.exit(s, :kill) end)
    data
  end
end
