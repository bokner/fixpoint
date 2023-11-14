defmodule CPSolver.Space do
  @moduledoc """
  Computation space.
  The concept is taken from Chapter 12, "Concepts, Techniques, and Models
  of Computer Programming" by Peter Van Roy and Seif Haridi.
  """

  alias CPSolver.Utils
  alias CPSolver.ConstraintStore
  alias CPSolver.Solution, as: Solution
  alias CPSolver.DefaultDomain, as: Domain
  alias CPSolver.Propagator.ConstraintGraph
  alias CPSolver.Utils
  alias CPSolver.Space.Propagation

  alias CPSolver.Shared

  require Logger

  @behaviour GenServer

  def default_space_opts() do
    [
      store_impl: CPSolver.ConstraintStore.default_store(),
      solution_handler: Solution.default_handler(),
      search: CPSolver.Search.Strategy.default_strategy(),
      solver_data: Shared.init_shared_data(),
      keep_alive: false
    ]
  end

  def create(variables, propagators, space_opts \\ default_space_opts()) do
    {:ok, _space} =
      create(%{
        variables: variables,
        propagators: Map.new(propagators, fn %{id: id} = p -> {id, p} end),
        constraint_graph: ConstraintGraph.create(propagators),
        opts: space_opts
      })
  end

  def create(data) do
    if CPSolver.complete?(data.opts[:solver_data]) do
      {:error, :complete}
    else
      GenServer.start(__MODULE__, data)
    end
  end

  @impl true
  def init(%{variables: variables, opts: space_opts} = data) do
    {:ok, space_variables, store} =
      ConstraintStore.create_store(variables,
        store_impl: space_opts[:store_impl],
        space: self()
      )

    space_data =
      data
      |> Map.put(:id, make_ref())
      |> Map.put(:variables, space_variables)
      |> Map.put(:store, store)

    {:ok, space_data, {:continue, :propagate}}
  end

  @impl true
  def handle_continue(:propagate, data) do
    propagate(data)
  end

  defp propagate(
         %{
           propagators: propagators,
           variables: variables,
           constraint_graph: constraint_graph,
           store: store
         } =
           data
       ) do
    Shared.add_active_spaces(data.opts[:solver_data], [self()])

    case Propagation.run(propagators, variables, constraint_graph, store) do
      :fail ->
        handle_failure(data)

      :solved ->
        handle_solved(data)

      {:stable, reduced_constraint_graph, reduced_propagators} ->
        %{
          data
          | constraint_graph: reduced_constraint_graph,
            propagators: reduced_propagators,
            variables: variables
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

  defp handle_stable(%{variables: variables} = data) do
    {localized_vars, _all_fixed?} = Utils.localize_variables(variables)
    distribute(%{data | variables: localized_vars})
  end

  def distribute(
        %{
          opts: opts,
          variables: localized_variables
        } = data
      ) do
    {:ok, {var_to_branch_on, domain_partitions}} = branching(localized_variables, opts[:search])

    Enum.map(domain_partitions, fn partition ->
      variable_copies =
        Enum.map(localized_variables, fn %{id: clone_id} = clone ->
          if clone_id == var_to_branch_on.id do
            Map.put(clone, :domain, Domain.new(partition))
          else
            clone
          end
        end)

      create(
        data
        |> Map.put(:variables, variable_copies)
      )
    end)

    shutdown(data, :distribute)
  end

  defp branching(variables, search_strategy) do
    case search_strategy.select_variable(variables) do
      {:ok, var_to_branch_on} ->
        var_domain = var_to_branch_on.domain

        case search_strategy.partition(var_domain) do
          :fail -> :fail
          {:ok, partitions} -> {:ok, {var_to_branch_on, partitions}}
        end

      error ->
        error
    end
  end

  defp shutdown(data, reason) do
    Shared.remove_space(data.opts[:solver_data], self(), reason)
    {:stop, :normal, data}
  end
end
