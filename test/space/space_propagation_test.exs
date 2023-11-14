defmodule CPSolverTest.SpacePropagation do
  use ExUnit.Case

  alias CPSolver.IntVariable, as: Variable
  alias CPSolver.Propagator.NotEqual
  alias CPSolver.ConstraintStore
  alias CPSolver.Space.Propagation
  alias CPSolver.Propagator.ConstraintGraph

  test "Propagation on stable space" do
    %{
      propagators: propagators,
      variables: [_x, y, _z] = variables,
      constraint_graph: graph,
      store: store
    } = stable_setup()

    {:stable, constraint_graph, stable_propagators} = Propagation.run(propagators, graph, store)
    assert Graph.num_vertices(constraint_graph) == 3

    assert map_size(stable_propagators) == 2

    assert [y] ==
             Enum.filter(variables, fn var ->
               Graph.has_vertex?(constraint_graph, {:variable, var.id})
             end)

    ## Variables in constraint graph in stable state are unfixed
    refute Variable.fixed?(y)

    propagators_from_graph =
      Enum.flat_map(
        Graph.vertices(constraint_graph),
        fn
          {:propagator, id} -> [ConstraintGraph.get_propagator(constraint_graph, id)]
          _ -> []
        end
      )

    assert length(propagators_from_graph) == 2

    propagator_vars_in_graph =
      Enum.map(propagators_from_graph, fn %{mod: NotEqual, args: vars} = _v ->
        Enum.map(vars, fn v -> v.name end)
      end)

    ## Both propagators in constraint graph have "y" variable
    assert Enum.all?(propagator_vars_in_graph, fn vars -> "y" in vars end)
  end

  test "Propagation on solvable space" do
    %{propagators: propagators, variables: variables, constraint_graph: graph, store: store} =
      solved_setup()

    refute Enum.all?(variables, fn var -> Variable.fixed?(var) end)
    assert :solved == Propagation.run(propagators, graph, store)
    assert Enum.all?(variables, fn var -> Variable.fixed?(var) end)
  end

  test "Propagation on failed space" do
    %{propagators: propagators, constraint_graph: graph, store: store} = fail_setup()
    assert :fail == Propagation.run(propagators, graph, store)
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

    {:ok, [x_var, y_var, z_var] = bound_vars, store} =
      ConstraintStore.create_store(variables)

    propagators =
      Enum.map(
        [{x_var, y_var}, {y_var, z_var}, {x_var, z_var}],
        fn {v1, v2} -> NotEqual.new([v1, v2]) end
      )

    graph = ConstraintGraph.create(propagators)

    %{
      propagators: Map.new(propagators, fn p -> {p.id, p} end),
      variables: bound_vars,
      constraint_graph: ConstraintGraph.remove_fixed(graph, bound_vars),
      store: store
    }
  end
end
