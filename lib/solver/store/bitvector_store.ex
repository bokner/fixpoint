defmodule CPSolver.Store.BitVector do
  alias CPSolver.DefaultDomain, as: Domain

  use CPSolver.ConstraintStore

  @impl true
  def create(variables, _opts \\ []) do

    variable_map = Map.new(
      variables,
      fn var ->
          {var.id, %{id: var.id, domain: Domain.new(var.domain)}}
      end
    )

    {:ok, variable_map}
  end

  @impl true
  def dispose(_store, _vars) do
    :ok
  end

  @impl true
  def get_variables(variable_map) do
    Enum.map(variable_map, fn {_id, var} -> var.id end)
  end

  @impl true
  def get(variable_map, variable, operation, args \\ []) do
    handle_request(:get, variable_map, variable, operation, args)
  end

  @impl true
  def update_domain(variable_map, variable, operation, args) do
    handle_request(:update, variable_map, variable, operation, args)
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
         _variable_map,
         domain,
         event
       ) do
    case event do
      :fixed -> {:fixed, Domain.min(domain)}
      event -> event
    end
  end

  @impl true
  def domain(_variable_map, variable) do
    Map.get(variable, :domain)
  end

  def lookup(variable_map, %{id: var_id} = _variable) do
    lookup(variable_map, var_id)
  end

  def lookup(variable_map, var_id) do
    Map.get(variable_map, var_id)
  end

  defp handle_request(kind, variable_map, variable, operation, args) do
    variable = lookup(variable_map, variable)
    handle_request_impl(kind, variable_map, variable.domain, operation, args)
  end

  def handle_request_impl(:get, _variable_map, domain, operation, args) do
    safe_apply(operation, domain, args)
  end

  def handle_request_impl(:update, variable_map, domain, operation, args) do
    case safe_apply(operation, domain, args) do
      :fail ->
        update_variable_domain(variable_map, :fail, :fail)

      :no_change ->
        :no_change

      {domain_change, new_domain} ->
        update_variable_domain(variable_map, new_domain, domain_change)
    end
  end

  defp safe_apply(operation, domain, args) do
    (Domain.fail?(domain) && :fail) ||
      apply(Domain, operation, [domain | args])
  end
end
