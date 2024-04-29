defmodule CPSolver.Space do
  @moduledoc """
  Computation space.
  The concept is taken from Chapter 12, "Concepts, Techniques, and Models
  of Computer Programming" by Peter Van Roy and Seif Haridi.
  """

  alias CPSolver.Variable.Interface
  alias CPSolver.DefaultDomain, as: Domain
  alias CPSolver.ConstraintStore
  alias CPSolver.Search.Strategy, as: Search
  alias CPSolver.Solution, as: Solution
  alias CPSolver.Propagator.ConstraintGraph
  alias CPSolver.Space.Propagation
  alias CPSolver.Objective

  alias CPSolver.Shared
  alias CPSolver.Distributed

  require Logger

  @behaviour GenServer

  def default_space_opts() do
    [
      store_impl: CPSolver.ConstraintStore.default_store(),
      solution_handler: Solution.default_handler(),
      search: Search.default_strategy(),
      max_space_threads: :erlang.system_info(:logical_processors),
      postpone: false,
      distributed: false
    ]
  end

  ## Top space creation
  def create(variables, propagators, space_opts \\ default_space_opts()) do
    propagators = maybe_add_objective_propagator(propagators, space_opts[:objective])

    space_data = %{
      variables: variables,
      propagators: propagators,
      constraint_graph: ConstraintGraph.create(propagators),
      opts: space_opts
    }

    create(space_data)
    |> tap(fn {:ok, space_pid} ->
      shared = shared(space_data)
      Shared.increment_node_counts(shared)
      Shared.add_active_spaces(shared, [space_pid])
    end)
  end

  ## Child space creation
  def create(data) do
    GenServer.start(__MODULE__, data)
  end

  defp maybe_add_objective_propagator(propagators, nil) do
    propagators
  end

  defp maybe_add_objective_propagator(propagators, objective) do
    [objective.propagator | propagators]
  end

  def start_propagation(space_pid) when is_pid(space_pid) do
    try do
      :done = GenServer.call(space_pid, :propagate, :infinity)
    catch
      :exit, {:normal, {GenServer, :call, _}} = _reason ->
        :ignore
    end
  end

  defp spawn_space(data) do
    solver = shared(data)
    worker_node = Distributed.choose_worker_node(solver.distributed)
    checked_out? = Shared.checkout_space_thread(solver, worker_node)
    run_space(worker_node, solver, data, checked_out?)
  end

  def run_space(worker_node, solver, data, checked_out?) do
    Shared.increment_node_counts(solver)

    (worker_node == Node.self() &&
       run_space(data, checked_out?)) ||
      :erpc.call(worker_node, __MODULE__, :run_space, [prepare_remote(data), checked_out?])
  end

  def run_space(data, checked_out?) do
    (checked_out? &&
       spawn(fn ->
         run_space(data)
         Shared.checkin_space_thread(shared(data))
       end)) ||
      run_space(data)
  end

  def run_space(data) do
    solver = shared(data)

    case create(
           data
           |> Map.put(:opts, Keyword.put(data.opts, :postpone, true))
         ) do
      {:ok, space_pid} ->
        Shared.add_active_spaces(solver, [space_pid])
        start_propagation(space_pid)

      {:error, _} ->
        :ignore
    end
  end

  ## Prepare local data to be used on remote node
  ## Currently we add the raw domain values to the opts,
  ## so the domains could be rebuilt on the remote nodes
  defp prepare_remote(data) do
    data
    |> Map.put(
      :domains,
      Map.new(data.variables, fn var ->
        {Interface.id(var), Interface.domain(var) |> Domain.to_list()}
      end)
    )
  end

  @impl true
  def init(%{domains: domains, variables: variables} = data) do
    updated_variables =
      Enum.map(variables, fn var ->
        domain = Map.get(domains, Interface.id(var))
        Map.put(var, :domain, Domain.new(domain))
      end)

    data
    |> Map.put(:variables, updated_variables)
    |> init_impl()
  end

  def init(data) do
    init_impl(data)
  end

  defp init_impl(%{variables: variables, opts: space_opts, constraint_graph: graph} = data) do
    {:ok, space_variables, store} =
      ConstraintStore.create_store(variables,
        store_impl: space_opts[:store_impl],
        space: self()
      )

    {constraint_graph, bound_propagators} = ConstraintGraph.update(graph, space_variables)

    space_data =
      data
      |> Map.put(:id, make_ref())
      |> Map.put(:variables, space_variables)
      |> Map.put(:store, store)
      |> Map.put(:constraint_graph, constraint_graph)
      |> Map.put(:objective, update_objective(space_opts[:objective], space_variables))
      |> Map.put(:propagators, bound_propagators)

    (space_opts[:postpone] &&
       {:ok, space_data}) || {:ok, space_data, {:continue, :propagate}}
  end

  @impl true
  def handle_continue(:propagate, data) do
    (data.opts[:postpone] && {:noreply, data}) ||
      data
      |> propagate()
      |> tap(fn _ ->
        caller = Map.get(data, :caller)
        caller && GenServer.reply(caller, :done)
      end)
  end

  @impl true
  def handle_call(:propagate, caller, data) do
    propagate(Map.put(data, :caller, caller))
  end

  defp propagate(
         %{
           propagators: propagators,
           constraint_graph: constraint_graph,
           store: store
         } =
           data
       ) do
    case Propagation.run(propagators, constraint_graph, store) do
      :fail ->
        handle_failure(data)

      :solved ->
        handle_solved(data)

      {:stable, reduced_constraint_graph} ->
        %{
          data
          | constraint_graph: reduced_constraint_graph
        }
        |> handle_stable()
    end
  end

  defp handle_failure(data) do
    shutdown(data, :failure)
  end

  defp handle_solved(data) do
    data
    |> solution()
    |> then(fn
      :fail ->
        shutdown(data, :fail)

      solution ->
        maybe_tighten_objective_bound(data[:objective])
        Solution.run_handler(solution, data.opts[:solution_handler])
        shutdown(data, :solved)
    end)
  end

  defp solution(%{variables: variables, store: store} = _data) do
    Enum.reduce_while(variables, Map.new(), fn var, acc ->
      case ConstraintStore.get(store, var, :min) do
        :fail -> {:halt, :fail}
        val -> {:cont, Map.put(acc, var.name, val)}
      end
    end)
  end

  defp maybe_tighten_objective_bound(nil) do
    :ok
  end

  defp maybe_tighten_objective_bound(objective) do
    Objective.tighten(objective)
  end

  defp update_objective(nil, _vars) do
    nil
  end

  defp update_objective(%{variable: variable} = objective, variables) do
    var_domain =
      Enum.at(variables, Interface.variable(variable).index - 1)
      |> Interface.domain()

    updated_var = Interface.update(variable, :domain, var_domain)
    Map.put(objective, :variable, updated_var)
    # objective
  end

  defp handle_stable(data) do
    try do
      distribute(data)
    catch
      :fail ->
        handle_failure(data)
    end
  end

  def distribute(
        %{
          opts: opts,
          variables: variables
        } = data
      ) do
    ## The search strategy branches off the existing variables.
    ## Each branch is a list of variables to use by a child space
    branches = Search.branch(variables, opts[:search])

    Enum.take_while(branches, fn variable_copies ->
      !CPSolver.complete?(shared(data)) &&
        spawn_space(data |> Map.put(:variables, variable_copies))
    end)

    shutdown(data, :distribute)
  end

  defp shutdown(data, reason) do
    {:stop, :normal, (!data[:finalized] && cleanup(data, reason)) || data}
  end

  defp shared(data) do
    data.opts[:solver_data]
  end

  defp cleanup(data, reason) do
    Shared.remove_space(shared(data), self(), reason)
    caller = data[:caller]
    caller && GenServer.reply(caller, :done)
    Map.put(data, :finalized, true)
  end

  @impl true
  def terminate(reason, data) do
    shutdown(data, reason)
  end
end
