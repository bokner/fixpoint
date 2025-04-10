defmodule CPSolver do
  @moduledoc """
  Solver API.
  """

  alias CPSolver.Model
  alias CPSolver.Space
  alias CPSolver.Solution
  alias CPSolver.Variable.Interface

  alias CPSolver.Shared

  use GenServer

  require Logger

  @default_timeout 30_000

  @doc """

  """
  @spec solve_async(Model.t(), Keyword.t()) :: {:ok, map()}
  def solve_async(model, opts \\ []) do
    opts = Keyword.merge(Space.default_space_opts(), opts)

    shared_data =
      Shared.init_shared_data(
        space_threads: opts[:space_threads],
        distributed: opts[:distributed]
      )
      |> Map.put(:sync_mode, opts[:sync_mode])

    {:ok, solver_pid} =
      GenServer.start(CPSolver, [model, Keyword.put(opts, :shared, shared_data)])

    {:ok,
     shared_data
     |> Map.put(:objective, strip_objective(Map.get(model, :objective)))
     |> Map.put(:solver_pid, solver_pid)
     |> Map.put(
       :variable_names,
       Enum.map(model.variables, fn var -> Interface.variable(var).name end)
     )}
  end

  defp strip_objective(nil) do
    nil
  end

  defp strip_objective(objective) do
    Map.drop(objective, [:variable, :propagator])
  end

  @spec solve(Model.t(), Keyword.t()) ::
          {:ok, map()} | {:error, reason :: any(), info :: any()}
  def solve(model, opts \\ []) do
    {:ok, solver} = solve_async(model, Keyword.put(opts, :sync_mode, true))

    :ok = wait_for_completion(solver, Keyword.get(opts, :timeout, @default_timeout))

    get_results(solver)
    |> tap(fn _ -> cleanup(solver) end)
  end

  @spec solve_sync(Model.t(), Keyword.t()) ::
          {:ok, map()} | {:error, reason :: any(), info :: any()}
  @deprecated "Use solve/2 instead"
  def solve_sync(model, opts \\ []) do
    solve(model, opts)
  end

  defp wait_for_completion(%{complete_flag: complete_flag} = solver, timeout) do
    receive do
      {:solver_completed, ^complete_flag} -> :ok
    after
      timeout ->
        Logger.error("Timeout waiting on solver completion")
        CPSolver.set_complete(solver)
    end
  end

  defp get_results(solver) do
    {:ok,
     %{
       statistics: statistics(solver),
       variables: solver.variable_names,
       solutions: solutions(solver),
       objective: objective_value(solver),
       status: status(solver)
     }}
  end

  def stop_spaces(solver) do
    Shared.stop_spaces(solver)
  end

  defp cleanup(solver) do
    Shared.cleanup(solver)
  end

  def statistics(solver) when is_pid(solver) do
    GenServer.call(solver, :get_stats)
  end

  def statistics(solver) when is_map(solver) do
    Shared.statistics(solver)
  end

  def status(solver) do
    status(statistics(solver), objective_value(solver), complete?(solver))
  end

  defp status(%{active_node_count: active_node_count, solution_count: 0}, _objective_value, true)
       when active_node_count <= 1 do
    :unsatisfiable
  end

  defp status(%{active_node_count: 0}, objective_value, true) do
    (objective_value && {:optimal, objective: objective_value}) || :all_solutions
  end

  defp status(
         %{active_node_count: active_nodes, solution_count: solution_count},
         objective_value,
         true
       )
       when active_nodes > 0 do
    if solution_count > 0 do
      (objective_value && {:satisfied, objective: objective_value}) || :satisfied
    else
      :unknown
    end
  end

  defp status(
         %{solution_count: solution_count},
         objective_value,
         false
       ) do
    (objective_value && {:running, solutions_found: solution_count, objective: objective_value}) ||
      {:running, solutions_found: solution_count}
  end

  def solutions(solver) when is_pid(solver) do
    GenServer.call(solver, :get_solutions)
  end

  def solutions(solver) when is_map(solver) do
    Shared.solutions(solver)
  end

  def objective_value(solver) do
    Shared.objective_value(solver)
  end

  def get_state(solver) when is_pid(solver) do
    :sys.get_state(solver)
  end

  def get_state(solver) when is_map(solver) do
    get_state(solver.solver_pid)
  end

  def complete?(solver) when is_map(solver) do
    Shared.complete?(solver)
  end

  def set_complete(solver) do
    Shared.set_complete(solver)
  end

  def dispose(solver) do
    cleanup(solver)
    Process.exit(solver.solver_pid, :normal)
  end

  def elapsed_time(solver) do
    Shared.elapsed_time(solver)
  end

  ## GenServer callbacks

  @impl true
  def init([%{propagators: propagators, variables: variables} = model, solver_opts]) do
    stop_on = Keyword.get(solver_opts, :stop_on)
    ## Some data (stats, solutions, possibly more - TBD) has to be shared between spaces
    shared = Keyword.get(solver_opts, :shared)

    variables = prepare(variables)

    objective = Map.get(model, :objective)


    {:ok,
     %{
       space: nil,
       variables: variables,
       propagators: propagators,
       objective: objective,
       shared: Map.put(shared, :objective, objective),
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
          objective: objective,
          solver_opts: solver_opts,
          shared: shared
        } = state
      ) do
    solution_handler_fun =
      solver_opts
      |> Keyword.get(:solution_handler, Solution.default_handler())
      |> build_solution_handler(state)
      |> Solution.solution_handler(variables)

    {:ok, top_space} =
      Space.create(
        variables,
        propagators,
        solver_opts
        |> Keyword.put(:objective, objective)
        |> Keyword.put(:solver_data, shared)
        |> Keyword.delete(:shared)
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

  ## Build a solution handler on top of initial one.
  ## For now, this adds handling logic for stop conditions
  defp build_solution_handler(solution_handler, solver_state) do
    stop_on_opt = get_in(solver_state, [:solver_opts, :stop_on])

    fn solution ->
      if not CPSolver.complete?(solver_state.shared) do
        solution
        |> Solution.run_handler(solution_handler)
        |> tap(fn _ -> Shared.add_solution(solver_state.shared, solution) end)
        |> tap(fn result -> check_stop_condition(stop_on_opt, result, solution, solver_state) end)
      end
    end
  end

  defp check_stop_condition(stop_on_opt, handler_result, solution, solver_state) do
    stop_on_opt &&
      condition_fun(stop_on_opt).(handler_result, solution, solver_state) &&
      Shared.set_complete(solver_state.shared)
  end

  defp condition_fun({:max_solutions, max_solutions}) do
    fn _handler_result, _solution, solver_state ->
      solution_count = Shared.statistics(solver_state.shared) |> Map.get(:solution_count, 0)
      max_solutions <= solution_count
    end
  end

  defp condition_fun(opts) do
    Logger.error("Stop condition with #{inspect(opts)} is not implemented")
  end

  defp prepare(variables) do
    ## At this point, `variables` list can contain views
    ## In this case, we will extract variables from views.
    Enum.reduce(variables, Arrays.new([], implementation: Aja.Vector), fn var,
    vars_acc ->
      Arrays.append(vars_acc, Interface.variable(var))
    end)
  end
end
