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

  def statistics(solver) when is_pid(solver) do
    GenServer.call(solver, :get_stats)
  end

  ## GenServer callbacks

  @impl true
  def init([%{constraints: constraints, variables: variables} = _model, solver_opts]) do
    propagators =
      Enum.reduce(constraints, [], fn constraint, acc ->
        acc ++ constraint_to_propagators(constraint)
      end)

    {:ok, top_space} =
      Space.create(variables, propagators, Keyword.put(solver_opts, :solver, self()))

    {:ok,
     %{
       space: top_space,
       variables: variables,
       solution_count: 0,
       failure_count: 0,
       node_count: 1,
       solver_opts: solver_opts
     }}
  end

  defp constraint_to_propagators(constraint) do
    [constraint_mod | args] = Tuple.to_list(constraint)
    constraint_mod.propagators(args)
  end

  @impl true
  def handle_info(event, state) do
    {:noreply, handle_event(event, state)}
  end

  defp handle_event({:solution, solution}, %{solution_count: count} = state) do
    Logger.debug("Solver: new solution")
    %{state | solution_count: count + 1}
    ## TODO: check for stopping condition here.
    ## Q: spaces are async and handle solutions on their own,
    ## so even if stopping condition is handled here, how do (or should)
    ## we prevent spaces from emitting new solutions?
  end

  defp handle_event(:failure, %{failure_count: count} = state) do
    Logger.debug("Solver: space failure")
    %{state | failure_count: count + 1}
  end

  defp handle_event({:nodes, n}, %{node_count: count} = state) do
    Logger.debug("Solver: #{n} new node(s)")
    %{state | node_count: count + n}
  end

  defp handle_event(unexpected, state) do
    Logger.error("Solver: unexpected message #{inspect(unexpected)}")
    state
  end

  @impl true
  def handle_call(:get_stats, _from, state) do
    {:reply, get_stats(state), state}
  end

  defp get_stats(state) do
    Map.take(state, [:solution_count, :failure_count, :node_count])
  end
end
