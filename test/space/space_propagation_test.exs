defmodule CPSolverTest.SpacePropagation do
  use ExUnit.Case

  alias CPSolver.IntVariable, as: Variable
  alias CPSolver.DefaultDomain, as: Domain
  alias CPSolver.Space.Propagation
  alias CPSolver.Test.Helpers

  test "Propagation on stable space" do
    %{
      propagators: _propagators,
      variables: [x, y, z] = _variables,
      constraint_graph: graph,
      store: store
    } = stable_setup()

    :solved = Propagation.run(graph, store)

    assert Variable.fixed?(x) && Variable.fixed?(z)
    ## Check not_equal(x, z)
    assert Variable.min(x) != Variable.min(z)
    refute Variable.fixed?(y)

    ## All values of reduced domain of 'y' participate in proper solutions.
    assert Enum.all?(Variable.domain(y) |> Domain.to_list(), fn y_value ->
             y_value != Variable.min(x) && y_value != Variable.min(z)
           end)
  end

  test "Propagation on solvable space" do
    %{variables: variables, constraint_graph: graph, store: store} =
      solved_setup()

    refute Enum.all?(variables, fn var -> Variable.fixed?(var) end)
    assert :solved == Propagation.run(graph, store)
    assert Enum.all?(variables, fn var -> Variable.fixed?(var) end)
  end

  test "Propagation on failed space" do
    %{constraint_graph: graph, store: store} = fail_setup()
    assert {:fail, _propagator_id} = Propagation.run(graph, store)
  end

  defp stable_setup() do
    x = 1..1
    y = -5..5
    z = 0..1

    space_setup(x, y, z)
  end

  defp solved_setup() do
    x = 1..1
    y = 0..2
    z = 0..1

    space_setup(x, y, z)
  end

  defp fail_setup() do
    x = 1..1
    y = 0..1
    z = 0..1

    space_setup(x, y, z)
  end

  defp space_setup(x, y, z) do
    Helpers.space_setup(x, y, z)
  end
end
