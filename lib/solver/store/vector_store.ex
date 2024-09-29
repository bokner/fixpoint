defmodule CPSolver.Store.Vector do
  alias CPSolver.DefaultDomain, as: Domain

  use CPSolver.ConstraintStore

  @impl true
  def create(variables, opts \\ [])

  def create(variables, _opts) when is_list(variables) do
    {:ok,
     Enum.reduce(variables, {Arrays.new([], implementation: Aja.Vector), 1}, fn var,
                                                                                {vector_acc,
                                                                                 idx_acc} ->
       {Arrays.append(vector_acc, Map.put(var, :index, idx_acc)), idx_acc + 1}
     end)
     |> elem(0)}
  end

  def create(variables, _opts) do
    {:ok, variables}
  end

  @impl true
  def dispose(_store, _vars) do
    :ok
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
         _table,
         _variable,
         _domain,
         event
       ) do
    event
  end

  @impl true
  def domain(vector, variable) do
    vector
    |> lookup(variable)
    |> Map.get(:domain)
  end

  def lookup(vector, %{index: index} = _variable) do
    lookup(vector, index)
  end

  def lookup(vector, index) do
    Arrays.get(vector, index - 1)
  end

  defp handle_request(kind, vector, var_id, operation, args) do
    variable = lookup(vector, var_id)
    handle_request_impl(kind, vector, variable, operation, args)
  end

  def handle_request_impl(:get, _vector, %{domain: domain} = _variable, operation, args) do
    apply(Domain, operation, [domain | args])
  end

  def handle_request_impl(:update, vector, %{domain: domain} = variable, operation, args) do
    case apply(Domain, operation, [domain | args]) do
      :fail ->
        update_variable_domain(vector, variable, :fail, :fail)

      :no_change ->
        :no_change

      :fixed ->
        update_variable_domain(vector, variable, domain, :fixed)

      {domain_change, new_domain} ->
        update_variable_domain(vector, variable, new_domain, domain_change)
    end
  end
end
