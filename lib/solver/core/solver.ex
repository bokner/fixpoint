defmodule CPSolver do
  @moduledoc """
  Solver API.
  """

  alias CPSolver.Model
  alias CPSolver.Space
  alias CPSolver.Constraint
  alias CPSolver.Solution
  alias CPSolver.Propagator

  alias CPSolver.Shared

  use GenServer

  require Logger

  @default_timeout 30_000

  @doc """

  """
  @spec solve(Model.t(), Keyword.t()) :: any()
  def solve(model, opts \\ []) do
    shared_data = Shared.init_shared_data() |> Map.put(:sync_mode, opts[:sync_mode])

    solver_model = Model.new(model)

    {:ok, solver_pid} =
      GenServer.start(CPSolver, [solver_model, Keyword.put(opts, :shared, shared_data)])

    {:ok,
     shared_data
     |> Map.put(:solver_pid, solver_pid)
     |> Map.put(:variable_names, Enum.map(solver_model.variables, & &1.name))}
  end

  @spec solve_sync(Model.t(), Keyword.t()) ::
          {:ok, map()} | {:error, reason :: any(), info :: any()}
  def solve_sync(model, opts \\ []) do
    {:ok, solver} = solve(model, Keyword.put(opts, :sync_mode, true))

    :ok = wait_for_completion(solver, Keyword.get(opts, :timeout, @default_timeout))

    get_results(solver)
    |> tap(fn _ -> cleanup(solver) end)
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
       solutions: solutions(solver)
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

  def complete?(solver) when is_map(solver) do
    Shared.complete?(solver)
  end

  def set_complete(solver) do
    Shared.set_complete(solver)
  end

  ## GenServer callbacks

  @impl true
  def init([%{constraints: constraints, variables: variables} = model, solver_opts]) do
    stop_on = Keyword.get(solver_opts, :stop_on)
    ## Some data (stats, solutions, possibly more - TBD) has to be shared between spaces
    shared = Keyword.get(solver_opts, :shared)

    {variables, propagators} = prepare(constraints, variables)

    {:ok,
     %{
       space: nil,
       variables: variables,
       propagators: propagators,
       objective: Map.get(model, :objective),
       shared: shared,
       stop_on: stop_on,
       solver_opts: Keyword.merge(Space.default_space_opts(), solver_opts)
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
      solution_count = Shared.statistics(solver_state.shared).solution_count
      max_solutions <= solution_count
    end
  end

  defp condition_fun(opts) do
    Logger.error("Stop condition with #{inspect(opts)} is not implemented")
  end

  defp prepare(constraints, variables) do
    indexed_variables =
      variables
      |> Enum.with_index(1)
      |> Map.new(fn {v, idx} -> {v.id, Map.put(v, :index, idx)} end)

    bound_propagators =
      Enum.reduce(constraints, [], fn constraint, acc ->
        acc ++
          Enum.map(Constraint.constraint_to_propagators(constraint), fn p ->
            Propagator.bind_to_variables(p, indexed_variables)
          end)
      end)

    {Map.values(indexed_variables) |> Enum.sort_by(fn v -> v.index end), bound_propagators}
  end
end
