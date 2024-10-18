defmodule CPSolver.Store.Local do
  alias CPSolver.DefaultDomain, as: Domain

  use CPSolver.ConstraintStore

  @impl true
  def create(variables, _opts \\ []) do
    {:ok, Enum.reduce(variables, {}, fn v, acc -> Tuple.append(acc, v.domain) end)}
  end

  @impl true
  def dispose(_store, _vars) do
    :ok
  end

  @impl true
  def get(domain_list, variable, operation, args \\ []) do
    handle_request(:get, domain_list, variable, operation, args)
  end

  @impl true
  def update_domain(domain_list, variable, operation, args) do
    handle_request(:update, domain_list, variable, operation, args)
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
         domain,
         event
       ) do
    case event do
      :fixed -> {:fixed, Domain.min(domain)}
      event -> event
    end
  end

  @impl true
  def domain(domain_list, variable) do
    elem(domain_list, variable.index - 1)
  end

  def handle_request(kind, domain_list, variable, operation, args) do
    handle_request_impl(kind, domain(domain_list, variable), operation, args)
  end

  def handle_request_impl(:get, domain, operation, args) do
    apply(Domain, operation, [domain | args])
  end

  def handle_request_impl(:update, domain, operation, args) do
    case apply(Domain, operation, [domain | args]) do
      :fail ->
        update_variable_domain(:fail, :fail)

      # throw(:fail)

      :no_change ->
        :no_change

      :fixed ->
        update_variable_domain(domain, :fixed)

      {domain_change, new_domain} ->
        update_variable_domain(new_domain, domain_change)
    end
  end
end
