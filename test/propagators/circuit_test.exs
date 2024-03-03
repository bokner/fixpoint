defmodule CPSolverTest.Propagator.Circuit do
  use ExUnit.Case

  alias CPSolver.ConstraintStore
  alias CPSolver.IntVariable, as: Variable
  alias CPSolver.Propagator
  alias CPSolver.Propagator.Circuit

  describe "Propagator filtering" do
    test "fixed variables: valid circuit" do
      valid_circuit = [2, 3, 4, 0, 5, 1]
      result = filter(valid_circuit)
      refute result.active?
    end

    test "fails on invalid circuit" do
      invalid_circuits =
        [
          [1, 2, 3, 4, 5, 2],
          [1, 2, 0, 4, 5, 3]
        ]

      Enum.all?(invalid_circuits, fn circuit -> filter(circuit) == :fail end)
    end
  end

  defp filter(domains) do
    variables =
      Enum.map(Enum.with_index(domains), fn {d, idx} -> Variable.new(d, name: "x#{idx}") end)

    {:ok, x_vars, _store} = ConstraintStore.create_store(variables)

    propagator = Circuit.new(x_vars)

    Propagator.filter(propagator)
  end
end
