defmodule CPSolver.Store.ETS do
  alias CPSolver.DefaultDomain, as: Domain

  use CPSolver.ConstraintStore

  @impl true
  def create(variables, opts \\ []) do
    ## TODO: there is a race condition for the updates that fix a variable.
    ## It goes like this:
    ## Propagators P1 and P2 run concurrently,
    ## and the filtering for each of them results
    ## in fixing the same variable.
    ## Filter calls for both P1 and P2 read the domain of the variable,
    ## but the updates are not aware that the domain may have already been fixed.
    ## The fix to follow; in the meantime, we reduce the probability of race condition
    ## by making reads and writes sequential.
    table_id =
      :ets.new(__MODULE__, [:set, :public, read_concurrency: false, write_concurrency: false])

    space = Keyword.get(opts, :space)

    store = %{
      space: space,
      handle: table_id,
      store_impl: __MODULE__
    }

    Enum.each(
      variables,
      fn var ->
        :ets.insert(
          table_id,
          {var.id, %{id: var.id, store: store, domain: Domain.new(var.domain)}}
        )
      end
    )

    {:ok, table_id}
  end

  @impl true
  def dispose(_store, _vars) do
    :ok
  end

  @impl true
  def get_variables(store) do
    :ets.tab2list(store) |> Enum.map(fn {_id, var} -> var.id end)
  end

  @impl true
  def get(store, variable, operation, args \\ []) do
    handle_request(:get, store, variable, operation, args)
  end

  @impl true
  def update_domain(store, variable, operation, args) do
    handle_request(:update, store, variable, operation, args)
  end

  @impl true
  def on_change(_store, _variable, _change) do
    :ok
  end

  @impl true
  def on_fix(_store, _variable, _value) do
    :ok
  end

  @impl true
  def on_no_change(_store, _variable) do
    :ok
  end

  @impl true
  def on_fail(_store, _variable) do
    :ok
  end

  defp update_variable_domain(
         table,
         variable,
         _domain,
         :fail
       ) do
    :ets.insert(table, {variable.id, Map.put(variable, :domain, :fail)})
    :fail
  end

  defp update_variable_domain(
         table,
         %{id: var_id} = variable,
         domain,
         event
       ) do
    :ets.insert(table, {var_id, Map.put(variable, :domain, domain)})

    case event do
      :fixed -> {:fixed, Domain.min(domain)}
      event -> event
    end
  end

  @impl true
  def domain(table, variable) do
    table
    |> lookup(variable)
    |> Map.get(:domain)
  end

  def lookup(table, %{id: var_id} = _variable) do
    lookup(table, var_id)
  end

  def lookup(table, var_id) do
    table
    |> :ets.lookup(var_id)
    |> hd
    |> elem(1)
  end

  defp handle_request(kind, table, var_id, operation, args) do
    variable = lookup(table, var_id)
    handle_request_impl(kind, table, variable, operation, args)
  end

  def handle_request_impl(_kind, _table, %{domain: :fail} = _variable, _operation, _args) do
    :fail
  end

  def handle_request_impl(:get, _table, %{domain: domain} = _variable, operation, args) do
    apply(Domain, operation, [domain | args])
  end

  def handle_request_impl(:update, table, %{domain: domain} = variable, operation, args) do
    case apply(Domain, operation, [domain | args]) do
      :fail ->
        update_variable_domain(table, variable, :fail, :fail)

      :no_change ->
        :no_change

      {domain_change, new_domain} ->
        update_variable_domain(table, variable, new_domain, domain_change)
    end
  end
end
