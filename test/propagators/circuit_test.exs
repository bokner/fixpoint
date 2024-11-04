defmodule CPSolverTest.Propagator.Circuit do
  use ExUnit.Case

  alias CPSolver.ConstraintStore
  alias CPSolver.IntVariable, as: Variable
  alias CPSolver.Variable.Interface
  alias CPSolver.Propagator
  alias CPSolver.Propagator.Circuit
  import CPSolver.Utils

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

      Enum.all?(invalid_circuits, fn circuit ->
        :fail ==
          try do
            filter(circuit)
          catch
            x -> x
          end
      end)
    end

    test "domains are cut accordingly on initialization" do
      n = 10
      domains = Enum.map(0..(n - 1), fn _idx -> -n..n end)
      propagator = make_propagator(domains)
      Propagator.filter(propagator)
      ## args of a propagator are bounded variables
      assert_initial_reduction(propagator)
    end

    test "filtering" do
      domains = [0..2, 0..2, 0..2]
      propagator = make_propagator(domains)
      [x0, x1, x2] = Arrays.to_list(propagator.args)
      res1 = Propagator.filter(propagator)

      assert_initial_reduction(propagator)

      ## Make x1 to be successor of x0
      Interface.fix(x0, 1)

      propagator1 = propagator |> Map.put(:state, res1.state)

      _res2 = Propagator.filter(propagator1)

      ## x0 is now a successor of x2
      assert Interface.fixed?(x2)
      assert Interface.min(x2) == 0
      ## x1 is also fixed
      assert Interface.fixed?(x1)
    end
  end

  defp filter(domains) do
    domains
    |> make_propagator()
    |> Propagator.filter()
  end

  defp make_propagator(domains) do
    variables =
      Enum.map(Enum.with_index(domains), fn {d, idx} -> Variable.new(d, name: "x#{idx}") end)

    {:ok, x_vars, _store} = ConstraintStore.create_store(variables)

    Circuit.new(x_vars)
  end

  defp assert_initial_reduction(propagator) do
    n = Arrays.size(propagator.args)

    assert Enum.all?(
             Enum.with_index(propagator.args),
             fn {var, idx} ->
               domain = domain_values(var)
               MapSet.new(domain) == MapSet.new(0..(n - 1)) |> MapSet.delete(idx)
             end
           )
  end
end
