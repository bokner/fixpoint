defmodule CPSolver.Store.PersistentTerm do
  alias CPSolver.DefaultDomain, as: Domain

  use CPSolver.ConstraintStore

  @impl true
  def create(variables, _opts \\ []) do
    ref = make_ref()

    :persistent_term.put(
      ref,
      Map.new(variables, fn var -> {var.id, var.domain} end)
    )

    {:ok, ref}
  end

  @impl true
  def dispose(term_ref, _vars) do
    :persistent_term.erase(term_ref)
  end

  @impl true
  def get(term_ref, variable, operation, args \\ []) do
    handle_request(:get, term_ref, variable, operation, args)
  end

  @impl true
  def update_domain(term_ref, variable, operation, args) do
    handle_request(:update, term_ref, variable, operation, args)
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
  def domain(term_ref, variable) do
    :persistent_term.get(term_ref) |> Map.get(variable.id)
  end

  def handle_request(kind, term_ref, variable, operation, args) do
    handle_request_impl(kind, domain(term_ref, variable), operation, args)
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
