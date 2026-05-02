defmodule CPSolver.Space do
  @moduledoc """
  Computation space.
  The concept is taken from Chapter 12, "Concepts, Techniques, and Models
  of Computer Programming" by Peter Van Roy and Seif Haridi.
  """

  alias CPSolver.Variable.Interface
  alias CPSolver.DefaultDomain, as: Domain
  alias CPSolver.Search, as: Search
  alias CPSolver.Solution, as: Solution
  alias CPSolver.Propagator.ConstraintGraph
  alias CPSolver.Propagator
  alias CPSolver.Space.Propagation
  alias CPSolver.Objective

  alias CPSolver.Shared
  alias CPSolver.Distributed
  alias CPSolver.Utils

  alias CPSolver.Utils.Vector
  alias InPlace.SparseSet

  require Logger

  def default_space_opts() do
    [
      solution_handler: Solution.default_handler(),
      search: Search.default_strategy(),
      space_threads: div(:erlang.system_info(:logical_processors), 2),
      distributed: false
    ]
  end

  ## Top space creation
  def create(
        %{variables: variables, propagators: propagators,
        objective: objective} = _state,
        space_opts \\ default_space_opts()
      ) do
    propagators =
      propagators
      |> assign_unique_ids()
      |> maybe_add_objective_propagator(objective)

    initial_constraint_graph = ConstraintGraph.create(propagators)
    num_variables = Vector.size(variables)
    unfixed_vars_tracker = SparseSet.new(num_variables)
    update_unfixed_variables(unfixed_vars_tracker, variables)

    space_data = %{
      parent_id: nil,
      id: make_ref(),
      variables: variables,
      unfixed_variables_tracker: unfixed_vars_tracker,
      propagators: propagators,
      objective: objective,
      constraint_graph: initial_constraint_graph,
      opts: space_opts
    }

    search = space_opts[:search]
    Search.initialize(search, space_data)
    ## Save initial constraint graph in shared data
    ## (for shared search strategies etc.)
    top_space_data =
      space_data
      |> Map.put(:search, search)
      |> put_shared(:initial_constraint_graph, initial_constraint_graph)

    shared = get_shared(space_data)
    Shared.increment_node_counts(shared)

    ## Create the 'top space' process and start propagation
    {:ok,
     spawn_link(fn ->
       top_space_data
       |> init_impl()
       |> tap(fn _ -> Shared.add_active_spaces(shared, [self()]) end)
       |> propagate()
     end)}
  end

  defp assign_unique_ids(propagators) do
    Enum.map(propagators, fn p -> Map.put(p, :id, make_ref()) end)
  end

  defp maybe_add_objective_propagator(propagators, nil) do
    propagators
  end

  defp maybe_add_objective_propagator(propagators, objective) do
    [objective.propagator | propagators]
  end

  defp update_unfixed_variables(tracker, variables) do
    SparseSet.each(tracker, fn var_idx ->
      Interface.fixed?(variables[var_idx - 1]) && SparseSet.delete(tracker, var_idx)
    end)
  end

  ## We had to serialize variable domains before sending variables
  ## to a remote node (see run_remote_space/3).
  ## Here we are restoring the domains and do branching.
  def remote_branching(search, %{domains: domains, variables: variables} = data) do
    ## Reconstruct variables with the domain values
    restored_variables =
      Enum.map(variables, fn var ->
        domain = Map.get(domains, Interface.id(var))
        Map.put(var, :domain, Domain.new(domain))
      end)

    Search.branch(restored_variables, search, Map.put(data, :variables, restored_variables))
  end

  defp run_branch(data, partition_fun) do
    solver = get_shared(data)

    if solver.distributed do
      worker_node = Distributed.choose_worker_node(solver.distributed)
      run_remote_space(worker_node, data, partition_fun)
    else
      run_space(data, partition_fun)
    end
  end

  defp run_remote_space(worker_node, data, partition_fun) do
    :erpc.call(worker_node, __MODULE__, :run_space, [prepare_remote(data), partition_fun])
  end

  ## This head is for handling remote space operations
  ## We had to serialize variable domains before sending variables
  ## to a remote node.
  ## Here we are restoring the domains and do branching.
  def run_space(%{domains: domains, variables: variables} = data, partition_fun) do
    restored_variables =
      Enum.map(variables, fn var ->
        domain = Map.get(domains, Interface.id(var))
        Map.put(var, :domain, Domain.new(domain))
      end)

    ## ..and we can now run it locally
    run_space(
      data
      |> Map.delete(:domains)
      |> Map.put(:variables, restored_variables),
      partition_fun
    )
  end

  def run_space(data, partition_fun) do
    solver = get_shared(data)
    Shared.increment_node_counts(solver)

    data = apply_partition(data, partition_fun)

    if checkout?(solver) do
      spawn(fn ->
        run_space_impl(data, solver)
        checkin(solver)
      end)
    else
      run_space_impl(data, solver)
    end
  end

  defp run_space_impl(data, solver) do
    Shared.add_active_spaces(solver, [self()])

    data
    |> init_impl()
    |> propagate()
  end

  defp apply_partition(%{variables: variables} = data, partition_fun) do
    %{
      variable_copies: branch_variables,
      domain_changes: changes,
      unfixed_variables_tracker: tracker
      } = partition_fun.(variables)

    data
    |> Map.put(:variables, branch_variables)
    |> Map.put(:unfixed_variables_tracker, tracker)
    |> put_in([:opts, :changes], changes)

  end

  ## Prepare local data to be used on remote node
  ## Currently we add the raw domain values to the opts,
  ## so the domains could be rebuilt on the remote nodes
  defp prepare_remote(data) do
    data
    |> Map.put(
      :domains,
      Map.new(data.variables, fn var ->
        {Interface.id(var), Utils.domain_values(var)}
      end)
    )
  end

  defp checkout?(solver) do
    Shared.checkout_space_thread(solver)
  end

  defp checkin(solver) do
    Shared.checkin_space_thread(solver)
  end

  defp init_impl(
         %{variables: variables, objective: objective, opts: space_opts, constraint_graph: graph} =
           data
       ) do
    data
    |> Map.put(:constraint_graph, update_constraint_graph(graph, variables))
    |> Map.put(:objective, update_objective(objective, variables))
    |> Map.put(:changes, Keyword.get(space_opts, :changes, %{}))
  end

  defp propagate(
         %{
           constraint_graph: constraint_graph,
           changes: changes
         } =
           data
       ) do
    try do
      case Propagation.run(constraint_graph, changes) do
        {:fail, _propagator_id} = failure ->
          handle_failure(data, failure)

        :solved ->
          handle_solved(data)

        {:stable, reduced_constraint_graph} ->
          Map.put(
            data,
            :constraint_graph,
            reduced_constraint_graph
          )
          |> handle_stable()
      end
    catch
      {:error, error} ->
        handle_error(error, data)
    end
  end

  defp handle_failure(data, failure) do
    Shared.add_failure(get_shared(data), failure)
    shutdown(data, :failure)
  end

  defp handle_solved(data) do
    process_solutions(data)
  end

  defp process_solutions(data) do
    maybe_tighten_objective_bound(data[:objective])
    ## Generate solutions and run them through solution handler.
    solutions(data)
    shutdown(data, :solved)
  end

  defp handle_error(exception, data) do
    Logger.error(inspect(exception))
    Shared.set_complete(get_shared(data))
    shutdown(data, :error)
  end

  defp solutions(%{variables: variables} = data) do
    try do
      Enum.map(variables, fn var ->
        Utils.domain_values(var)
      end)
      |> Utils.lazy_cartesian(fn values ->
        values
        |> Enum.reverse()
        |> Enum.zip(variables)
        |> Map.new(fn {val, variable} ->
          {variable.name, val}
        end)
        |> Solution.run_handler(data.opts[:solution_handler])
        |> tap(fn handler_result ->
          cond do
            CPSolver.complete?(get_shared(data)) ->
              ## Stop producing solutions if the solving is complete
              throw(:complete)

            data[:objective] ->
              ## Stop producing solutions is it's an optimization problem.
              ## This will avoid solutions with the same objective value
              throw({:same_objective, handler_result})

            true ->
              handler_result
          end
        end)
      end)
    catch
      :complete -> :complete
      {:same_objective, handler_result} -> handler_result
    end
  end

  defp maybe_tighten_objective_bound(nil) do
    :ok
  end

  defp maybe_tighten_objective_bound(objective) do
    Objective.tighten(objective)
  end

  defp update_constraint_graph(graph, variables) do
    graph
    |> ConstraintGraph.copy()
    |> ConstraintGraph.update(variables)
  end

  defp update_objective(nil, _vars) do
    nil
  end

  defp update_objective(%{variable: variable} = objective, variables) do
    updated_var = update_domain(variable, variables)
    Map.put(objective, :variable, updated_var)
  end

  defp update_domain(variable, space_variables) do
    var_domain =
      Propagator.arg_at(space_variables, Interface.variable(variable).index - 1)
      |> Interface.domain()

    Interface.update(variable, :domain, var_domain)
  end

  defp handle_stable(data) do
    if CPSolver.complete?(get_shared(data)) do
      shutdown(data, :distribute)
    else
      distribute(data)
    end
  end

  def distribute(
        %{
          id: id,
          variables: variables,
          constraint_graph: _graph,
          search: search
        } = data
      ) do
    try do
      variables
      |> Search.branch(search, data)
      |> Enum.take_while(fn partition_fun ->
        if CPSolver.complete?(get_shared(data)) do
          false
        else
          run_branch(
            data
            |> Map.put(:parent_id, id)
            |> Map.put(:id, make_ref()),
            partition_fun
          )

          true
        end
      end)

      shutdown(data, :distribute)
    catch
      :all_vars_fixed ->
        process_solutions(data)

      :fail ->
        handle_failure(data, :failure)
    end
  end

  defp shutdown(data, reason) do
    Shared.finalize_space(get_shared(data), data, self(), reason)
  end

  def get_shared(data) do
    data.opts[:solver_data]
  end

  def put_shared(data, key, value) do
    data
    |> tap(fn _ -> Shared.put_auxillary(get_in(data, [:opts, :solver_data]), key, value) end)
  end
end
