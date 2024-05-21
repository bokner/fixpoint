defmodule DebugCircuit do
  alias CPSolver.ConstraintStore
  alias CPSolver.IntVariable, as: Variable
  alias CPSolver.Variable.Interface
  alias CPSolver.DefaultDomain, as: Domain
  alias CPSolver.Propagator
  alias CPSolver.Propagator.Circuit

  def run(domains) do
  end

  def filter(domains) do
    domains
    |> make_propagator()
    |> Propagator.filter()
  end

  def make_propagator(domains) do
    variables =
      Enum.map(Enum.with_index(domains), fn {d, idx} -> Variable.new(d, name: "x#{idx}") end)

    {:ok, x_vars, _store} = ConstraintStore.create_store(variables)

    Circuit.new(x_vars)
  end
end
