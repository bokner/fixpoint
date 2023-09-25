defmodule CPSolver do
  @moduledoc """
  Solver API.
  """

  alias CPSolver.Space
  alias CPSolver.Propagator
  use GenServer

  require Logger

  @doc """

  """
  @spec solve(Model.t(), Keyword.t()) :: any()
  def solve(model, opts \\ []) do
    {:ok, _solver} = GenServer.start_link(CPSolver, [model, opts])
  end

  def statistics(solver) when is_pid(solver) do
    GenServer.call(solver, :get_stats)
  end

  def solutions(solver) when is_pid(solver) do
    GenServer.call(solver, :get_solutions)
  end

  ## GenServer callbacks

  @impl true
  def init([%{constraints: constraints, variables: variables} = _model, solver_opts]) do
    propagators =
      Enum.reduce(constraints, [], fn constraint, acc ->
        acc ++ constraint_to_propagators(constraint)
      end)

    stop_on = Keyword.get(solver_opts, :stop_on)

    {:ok,
     %{
       space: nil,
       variables: variables,
       propagators: propagators,
       solution_count: 0,
       failure_count: 0,
       node_count: 1,
       solutions: [],
       active_nodes: MapSet.new(),
       stop_on: stop_on,
       solver_opts: solver_opts
     }, {:continue, :solve}}
  end

  defp constraint_to_propagators(constraint) do
    [constraint_mod | args] = Tuple.to_list(constraint)
    constraint_mod.propagators(List.flatten(args))
  end

  @impl true
  def handle_continue(
        :solve,
        %{variables: variables, propagators: propagators, solver_opts: solver_opts} = state
      ) do
    {:ok, top_space} =
      Space.create(
        variables,
        propagators |> Enum.map(&Propagator.normalize/1),
        Keyword.put(solver_opts, :solver, self())
      )

    {:noreply, Map.put(state, :space, top_space)}
  end

  @impl true
  def handle_info(event, state) do
    {:noreply, handle_event(event, state)}
  end

  defp handle_event(
         {:solution, new_solution},
         %{solution_count: count, solutions: solutions, stop_on: stop_on} = state
       ) do
    if check_for_stop(stop_on, new_solution, state) do
      stop_spaces(state)
    else
      %{state | solution_count: count + 1, solutions: [new_solution | solutions]}
    end

    ## TODO: check for stopping condition here.

    ## Q: spaces are async and handle solutions on their own,
    ## so even if stopping condition is handled here, how do (or should)
    ## we prevent spaces from emitting new solutions?
  end

  defp handle_event(:failure, %{failure_count: count} = state) do
    Logger.debug("Solver: space failure")
    %{state | failure_count: count + 1}
  end

  defp handle_event({:nodes, new_nodes}, %{node_count: count, active_nodes: nodes} = state) do
    new_nodes_set = MapSet.new(new_nodes)
    n = MapSet.size(new_nodes_set)
    Logger.debug("Solver: #{n} new node(s)")
    %{state | node_count: count + n, active_nodes: MapSet.union(nodes, new_nodes_set)}
  end

  defp handle_event({:shutdown_space, node}, %{active_nodes: nodes} = state) do
    %{state | active_nodes: MapSet.delete(nodes, node)}
  end

  defp handle_event(unexpected, state) do
    Logger.error("Solver: unexpected message #{inspect(unexpected)}")
    state
  end

  @impl true
  def handle_call(:get_stats, _from, state) do
    {:reply, get_stats(state), state}
  end

  def handle_call(:get_solutions, _from, state) do
    {:reply, get_solutions(state), state}
  end

  defp get_stats(state) do
    Map.take(state, [:solution_count, :failure_count, :node_count])
  end

  defp get_solutions(%{solutions: solutions} = _state) do
    ## Here we piggy-back on the fact that the variables are ordered by their refs
    ## in spaces, and the order there matches the order within solver state.
    ## This may likely change, we will probably use var names instead of refs.
    solutions
    |> Enum.map(fn solution ->
      solution
      |> Enum.sort_by(fn {ref, _value} -> ref end)
      |> Enum.map(fn {_ref, value} -> value end)
    end)
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
