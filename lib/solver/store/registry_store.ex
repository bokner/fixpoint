defmodule CPSolver.Store.Registry do
  alias CPSolver.ConstraintStore, as: Store
  alias CPSolver.DefaultDomain, as: Domain
  alias CPSolver.Variable
  alias CPSolver.Utils

  require Logger

  @behaviour Store

  @variable_registry CPSolver.Store.Registry

  @impl true
  @spec create(any(), [Variable.t()]) :: {:ok, [any()]}
  def create(space, variables) do
    Registry.start_link(name: @variable_registry, keys: :unique)

    {:ok,
     Enum.map(
       variables,
       fn var ->
         {:ok, _pid} =
           Agent.start_link(
             fn ->
               Domain.new(var.domain)
               |> tap(fn _ ->
                 Process.put(:fire_on_no_change, true)
                 {:ok, _} = Registry.register(@variable_registry, var.id, space)
               end)
             end,
             name: variable_proc_id(var)
           )

         var
         |> Map.put(:space, space)
       end
     )}
  end

  def variable_proc_id(variable) do
    {:global, variable.id}
  end

  @impl true
  def get(_store, var, operation, args \\ []) do
    Agent.get(
      variable_proc_id(var),
      fn
        :fail ->
          :fail
          |> tap(fn _ -> handle_op_on_failed_var(var, operation) end)

        domain ->
          apply(Domain, operation, [domain | args])
      end
    )
  end

  @impl true
  def update(_store, var, operation, args \\ []) do
    Agent.update(
      variable_proc_id(var),
      fn
        :fail ->
          :fail
          |> tap(fn _ -> handle_op_on_failed_var(var, operation) end)

        domain ->
          case apply(Domain, operation, [domain | args]) do
            :fail ->
              :fail
              |> tap(fn _ -> handle_failure(var) end)

            :none ->
              domain
              |> tap(fn _ -> handle_domain_no_change(var) end)

            {domain_change, new_domain} ->
              new_domain
              |> tap(fn _ -> handle_domain_change(domain_change, var, new_domain) end)
          end
      end
    )
  end

  defp handle_failure(var) do
    Logger.debug("Failure for variable #{inspect(var.id)}")
    ## TODO: notify space (and maybe don't notify propagators)
    publish(var, {:fail, var.id})
  end

  defp handle_op_on_failed_var(var, operation) do
    Logger.warning(
      "Attempt to request #{inspect(operation)} on failed variable #{inspect(var.id)}"
    )
  end

  defp handle_domain_no_change(var) do
    ## Publish no_change only once between domain change events
    fire_on_no_change?() &&
      publish(var, {:no_change, var.id})
      |> tap(fn _ ->
        Logger.debug("No change for variable #{inspect(var.id)}")
        Process.put(:fire_on_no_change, false)
      end)
  end

  defp handle_domain_change(domain_change, var, _domain) do
    publish(var, {domain_change, var.id})
    |> tap(fn _ ->
      Logger.debug("Domain change (#{domain_change}) for #{inspect(var.id)}")
      Process.put(:fire_on_no_change, true)
    end)
  end

  defp publish(var, message) do
    Utils.publish(Variable.topic(var), message)
  end

  defp fire_on_no_change?() do
    Process.get(:fire_on_no_change)
  end

  @impl true
  @spec get_variables(any()) :: [reference()]
  def get_variables(space) do
    Registry.select(CPSolver.Store.Registry, [
      {{:"$1", :_, :"$3"}, [{:==, :"$3", space}], [:"$1"]}
    ])
  end
end
