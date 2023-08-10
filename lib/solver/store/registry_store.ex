defmodule CPSolver.Store.Registry do
  alias CPSolver.ConstraintStore, as: Store
  alias CPSolver.DefaultDomain, as: Domain

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
         variable_id = make_ref()

         {:ok, _pid} =
           Agent.start_link(
             fn ->
               Domain.new(var.domain)
               |> tap(fn _ ->
                 {:ok, _} = Registry.register(@variable_registry, variable_id, space)
               end)
             end,
             name: variable_proc_id(variable_id)
           )

         var
         |> Map.put(:space, space)
         |> Map.put(:id, variable_id)
       end
     )}
  end

  def variable_proc_id(variable_id) do
    {:global, variable_id}
  end

  @impl true
  def get(_store, var_id, operation, args \\ []) do
    Agent.get(
      variable_proc_id(var_id),
      fn
        :fail ->
          :fail

        domain ->
          apply(Domain, operation, [domain | args])
      end
    )
  end

  @impl true
  def update(_store, var_id, operation, args \\ []) do
    Agent.update(
      variable_proc_id(var_id),
      fn
        :fail ->
          :fail
          |> tap(fn _ -> Logger.warn("Attempt to update failed variable #{inspect(var_id)}") end)

        domain ->
          case apply(Domain, operation, [domain | args]) do
            :fail ->
              :fail
              |> tap(fn _ -> handle_failure(var_id) end)

            {domain_change, new_domain} ->
              new_domain
              |> tap(fn _ -> handle_domain_change(domain_change, var_id, new_domain) end)
          end
      end
    )
  end

  defp handle_failure(var_id) do
    Logger.debug("Failure for variable #{inspect(var_id)}")
  end

  defp handle_domain_change(domain_change, var_id, _domain) do
    Logger.debug("Domain change (#{domain_change}) for #{inspect(var_id)}")
  end

  @impl true
  @spec get_variables(any()) :: [reference()]
  def get_variables(space) do
    Registry.select(CPSolver.Store.Registry, [
      {{:"$1", :_, :"$3"}, [{:==, :"$3", space}], [:"$1"]}
    ])
  end
end
