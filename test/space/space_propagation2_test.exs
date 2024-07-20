defmodule CPSolverTest.SpacePropagation2 do
  use ExUnit.Case

  alias CPSolver.IntVariable, as: Variable
  alias CPSolver.Propagator.NotEqual
  alias CPSolver.Space.Propagation2, as: Propagation
  alias CPSolver.Propagator
  alias CPSolver.Propagator.ConstraintGraph
  import CPSolver.Test.Helpers

  test "Propagation on solvable space" do
    %{
      propagators: propagators,
      variables: [x, y, z] = variables,
      constraint_graph: graph
    } = solved_setup()

    :solved = Propagation.run(graph, propagators, variables: variables)

    ## 'x' and 'z' variables are fixed
    assert Enum.all?([x, z], fn v -> Variable.fixed?(v) end)
    ## values of 'x' and 'z' are removed from 'y' domain
    refute Enum.all?([x, z], fn v -> Variable.contains?(y, Variable.min(v)) end)
    ## 'y' is not fixed
    refute Variable.fixed?(y)
  end

  test "Propagation to stable space" do
    %{
      propagators: propagators,
      variables: [x, y, z] = variables,
      constraint_graph: graph
    } = stable_setup()

    {:stable, constraint_graph} = Propagation.run(graph, propagators, variables: variables)
    assert Graph.num_vertices(constraint_graph) == 3

    assert [y, z] ==
             Enum.filter(variables, fn var ->
               Graph.has_vertex?(constraint_graph, {:variable, var.id})
             end)

    ## In stable state, variables referenced in constraint graph are unfixed.
    assert Variable.fixed?(x)
    refute Variable.fixed?(y)
    refute Variable.fixed?(z)

    propagators_from_graph =
      Enum.flat_map(
        Graph.vertices(constraint_graph),
        fn
          {:propagator, id} -> [ConstraintGraph.get_propagator(constraint_graph, id)]
          _ -> []
        end
      )

    assert length(propagators_from_graph) == 1
    ## The 'y != z' propagator is in the graph
    yz_propagator = hd(propagators_from_graph)
    assert yz_propagator.name == "y != z"

  end

  test "Propagation on failed space" do
    %{propagators: propagators, constraint_graph: graph, variables: variables} = fail_setup()
    assert :fail == Propagation.run(graph, propagators, variables: variables)
  end

  test "Single propagator" do
    x = 0..1
    y = 1
    variables =
      Enum.map([{x, "x"}, {y, "y"}], fn {d, name} -> Variable.new(d, name: name) end)

    {:ok, bound_vars, _store} =
      create_store(variables)

    [x_var, y_var] = bound_vars
    p = Propagator.new(NotEqual, [x_var, y_var])
    graph = ConstraintGraph.create([p])

    assert :solved == Propagation.run(graph, [p], variables: bound_vars)
    assert Variable.fixed?(x_var) && Variable.fixed?(y_var) && Variable.min(x_var) == 0

  end


  defp solved_setup() do
    x = 1..1
    y = -5..5
    z = 0..1

    space_setup(x, y, z)
  end

  defp stable_setup() do
    x = 1..1
    y = -5..5
    z = 0..2

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

    [x_var, y_var, z_var] = bound_vars

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
