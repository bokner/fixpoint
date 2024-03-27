defmodule CPSolver.Search.DomainPartition do
  alias CPSolver.DefaultDomain, as: Domain
  alias CPSolver.Variable.Interface

  require Logger

  def partition(variable, strategy) when is_function(strategy) do
    try do
      domain = Interface.domain(variable)
      split_domain_by(domain, strategy.(variable))
    catch
      :fail ->
        Logger.error("Failure on partition: #{inspect(variable)}")
        {:ok, []}
    end
  end

  def partition(variable, choice) when choice in [:min, :max] do
    domain = Interface.domain(variable)
    val = apply(Domain, choice, [domain])
    split_domain_by(domain, val)
  end

  def by_min(variable) do
    partition(variable, :min)
  end

  def by_max(variable) do
    partition(variable, :max)
  end

  def random(variable) do
    domain = Interface.domain(variable)
    random_val = Domain.to_list(domain) |> Enum.random()
    split_domain_by(domain, random_val)
  end

  def split_domain_by(domain, value) do
    Domain.remove(domain, value)
    {:ok, [Domain.new(value), domain]}
  end
end
