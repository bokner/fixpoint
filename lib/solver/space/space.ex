defmodule CPSolver.Space do
  @moduledoc """
  Computation space.
  The concept is taken from Chapter 12, "Concepts, Techniques, and Models
  of Computer Programming" by Peter Van Roy and Seif Haridi.
  """

  alias CPSolver.Utils
  alias CPSolver.ConstraintStore
  alias CPSolver.Propagator
  alias CPSolver.Solution, as: Solution
  alias CPSolver.IntVariable, as: Variable
  alias CPSolver.DefaultDomain, as: Domain
  alias CPSolver.Propagator.ConstraintGraph
  alias CPSolver.Utils
  alias CPSolver.Space.Propagation

  alias CPSolver.Shared

  require Logger

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
    if CPSolver.complete?(space_opts[:solver_data]) do
      {:error, :complete}
    else
      {:ok, _space} =
        create(%{
          variables: variables,
          propagators: Map.new(propagators, fn p -> {make_ref(), Propagator.normalize(p)} end),
          opts: space_opts
        })
    end
  end

  def create(%{variables: variables, propagators: propagators, opts: space_opts} = data) do
    space_id = make_ref()

    {:ok, space_variables, store} =
      ConstraintStore.create_store(variables,
        store_impl: space_opts[:store_impl],
        space: self(),
        constraint_graph: nil
      )

    space_propagators =
      bind_propagators(propagators, store)

    space_data = %{
      id: space_id,
      variables: space_variables,
      propagators: space_propagators,
      constraint_graph:
        Map.get(data, :constraint_graph) || ConstraintGraph.create(space_propagators),
      store: store,
      opts: space_opts
    }

    propagate(space_data)
  end

  defp bind_propagators(propagators, store) do
    Map.new(
      propagators,
      fn {ref, {mod, args}} ->
        {ref,
         {mod,
          Enum.map(args, fn
            %CPSolver.Variable{} = arg -> Map.put(arg, :store, store)
            const -> const
          end)}}
      end
    )
  end

  def propagate(
        %{propagators: propagators, variables: variables, constraint_graph: constraint_graph} =
          data
      ) do
    Shared.add_active_spaces(data.opts[:solver_data], [self()])

    case Propagation.run(propagators, variables, constraint_graph) do
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
        handle_failure(data)

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
    Logger.error("Distribute: #{inspect(localized_variables)}")

    case branching(localized_variables, opts[:search]) do
      {:ok, {var_to_branch_on, domain_partitions}} ->
        Enum.map(domain_partitions, fn partition ->
          variable_copies =
            Enum.map(localized_variables, fn %{id: clone_id} = clone ->
              if clone_id == var_to_branch_on.id do
                Variable.copy(clone) |> Map.put(:domain, Domain.new(partition))
              else
                Variable.copy(clone)
              end
            end)

          create(
            data
            |> Map.put(:variables, variable_copies)
          )
        end)

        shutdown(data, :distribute)
    end
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
  end

  def get_state_and_data(space) do
    {_state, _data} = :sys.get_state(space)
  end
end
