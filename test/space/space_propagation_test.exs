defmodule CPSolverTest.SpacePropagation do
  use ExUnit.Case

  alias CPSolver.IntVariable, as: Variable
  alias CPSolver.DefaultDomain, as: Domain
  alias CPSolver.Propagator.NotEqual
  alias CPSolver.Space.Propagation
  alias CPSolver.Propagator
  alias CPSolver.Propagator.ConstraintGraph
  import CPSolver.Test.Helpers

  test "Propagation on stable space" do
    %{
      propagators: propagators,
      variables: [x, y, z] = variables,
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
    assert :fail == Propagation.run(graph, store)
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
    variables =
      Enum.map([{x, "x"}, {y, "y"}, {z, "z"}], fn {d, name} -> Variable.new(d, name: name) end)

    {:ok, bound_vars, store} =
      create_store(variables)

    bound_vars = [x_var, y_var, z_var] = bound_vars

    propagators =
      Enum.map(
        [{x_var, y_var, "x != y"}, {y_var, z_var, "y != z"}, {x_var, z_var, "x != z"}],
        fn {v1, v2, name} -> Propagator.new(NotEqual, [v1, v2], name: name) end
      )

    graph = ConstraintGraph.create(propagators)

    {updated_graph, _bound_propagators} = ConstraintGraph.update(graph, bound_vars)

    %{
      propagators: propagators,
      variables: bound_vars,
      constraint_graph: updated_graph,
      store: store
    }
  end
end
