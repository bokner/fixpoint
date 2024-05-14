defmodule CPSolverTest.SpacePropagation do
  use ExUnit.Case

  alias CPSolver.IntVariable, as: Variable
  alias CPSolver.Propagator.NotEqual
  alias CPSolver.ConstraintStore
  alias CPSolver.Space.Propagation
  alias CPSolver.Propagator
  alias CPSolver.Propagator.ConstraintGraph

  test "Propagation on stable space" do
    %{
      propagators: propagators,
      variables: [_x, y, _z] = variables,
      constraint_graph: graph,
      store: store
    } = stable_setup()

    {:stable, constraint_graph} = Propagation.run(propagators, graph, store)
    assert Graph.num_vertices(constraint_graph) == 3

    assert [y] ==
             Enum.filter(variables, fn var ->
               Graph.has_vertex?(constraint_graph, {:variable, var.id})
             end)

    ## In stable state, variables referenced in constraint graph are unfixed.
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

  test "Propagation pass" do
    x = 1..1
    y = 1..2
    z = 1..3
    %{propagators: propagators, constraint_graph: graph, store: store} = space_setup(x, y, z)

    {scheduled_propagators, reduced_graph, domain_changes} =
      Propagation.propagate(propagators, graph, store)

    assert Enum.all?(scheduled_propagators, fn p_id -> p_id in Map.keys(domain_changes) end)

    ## Domain s changes are `pos => domain_change` maps, where `pos` is the position
    ## of a variable in the propagator arguments
    assert Enum.all?(propagators, fn p ->
             propagator_domain_changes = Map.get(domain_changes, p.id)
             var_id_set = MapSet.new(Enum.map(p.args, fn v -> v.id end))

             MapSet.subset?(
               Enum.map(propagator_domain_changes, fn {var_pos, _change} ->
                 Enum.at(p.args, var_pos).id
               end)
               |> MapSet.new(),
               var_id_set
             )
           end)

    ## Propagators are not being rescheduled
    ## as a result of their own filtering (idempotency).
    ##
    ## Only NotEqual(y, z) is rescheduled.
    ## Explanation:
    ## - NotEqual(x, y) changes y => schedules NotEqual(y,z);
    ## - NotEqual(x, z) changes z => schedules NotEqual(y,z);
    ## - NotEqual(y, z) changes z and/or y (if not called first) as a result of it's own filtering.
    ## So, at no point NotEqual(x, y) and NotEqual(x, z) are being rescheduled.

    [not_equal_y_z_reference] = MapSet.to_list(scheduled_propagators)
    not_equal_y_z = ConstraintGraph.get_propagator(reduced_graph, not_equal_y_z_reference)
    assert not_equal_y_z.mod == NotEqual

    assert not_equal_y_z.name == "y != z"
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
