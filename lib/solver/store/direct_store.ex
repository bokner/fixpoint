defmodule CPSolver.Store.Direct do
  alias CPSolver.DefaultDomain, as: Domain

  use CPSolver.ConstraintStore

  @impl true
  def create(_variables, _opts \\ []) do
    {:ok, {:direct_store, make_ref()}}
  end

  @impl true
  def dispose(_store, _vars) do
    :ok
  end

  @impl true
  def get(_store, variable, operation, args \\ []) do
    handle_request(:get, variable, operation, args)
  end

  @impl true
  def update_domain(_store, variable, operation, args) do
    handle_request(:update, variable, operation, args)
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
         _variable,
         _domain,
         event
       ) do
    event
  end

  @impl true
  def domain(_store, %{domain: domain} = _variable) do
    domain
  end

  def handle_request(:get, %{domain: domain} = _variable, operation, args) do
    apply(Domain, operation, [domain | args])
  end

  def handle_request(:update, %{domain: domain} = variable, operation, args) do
    case apply(Domain, operation, [domain | args]) do
      :fail ->
        :fail

      :no_change ->
        :no_change

      :fixed ->
        update_variable_domain(variable, domain, :fixed)

      {domain_change, new_domain} ->
        update_variable_domain(variable, new_domain, domain_change)
    end
  end
end
