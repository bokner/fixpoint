defmodule CPSolverTest.Propagator.ConstraintGraph do
  use ExUnit.Case
  require Logger

  describe "Propagator graph" do
    alias CPSolver.Propagator.ConstraintGraph
    alias CPSolver.Constraint.AllDifferent.Binary, as: AllDifferent
    alias CPSolver.Constraint
    alias CPSolver.Propagator
    alias CPSolver.IntVariable, as: Variable
    alias CPSolver.Variable.Interface
    alias CPSolver.DefaultDomain, as: Domain

    test "Build graph from AllDifferent constraint" do
      graph = build_graph(AllDifferent, 3)
      ## Vertices: 3 propagators (x != y, y != z, x != z) and 3 variables
      assert length(Graph.vertices(graph)) == 6
      ## Edges: 2 per each propagator
      assert length(Graph.edges(graph)) == 6
      ## All edges are labeled with :fixed
      Enum.all?(Graph.edges(graph), fn edge -> assert edge.label.propagate_on == [:fixed] end)
      ## Make sure the propagators are properly bound to their variables
      assert_propagator_domains(graph, 1..3)
    end

    test "Get propagators for the given variable and domain event" do
      graph = build_graph(AllDifferent, 3)

      variables =
        Graph.vertices(graph)
        |> Enum.flat_map(fn
          {:variable, v} -> [v]
          _ -> []
        end)

      ## For each variable, there are 2 propagators listening to ':fixed' domain change
      Enum.all?(variables, fn var_id ->
        assert map_size(ConstraintGraph.get_propagator_ids(graph, var_id, :fixed)) == 2
      end)
    end

    test "Remove variables" do
      graph = build_graph(AllDifferent, 3)

      variables =
        [v1, _v2, _v3] = get_variable_ids(graph)


      assert graph |> ConstraintGraph.remove_variable(v1) |> Graph.edges() |> length == 4

      assert Enum.reduce(variables, graph, fn v, g ->
               assert Graph.vertices(g) != []
               ConstraintGraph.remove_variable(g, v)
             end)
             |> Graph.edges() == []
    end

    test "Update graph variables" do
      graph = build_graph(AllDifferent, 3)
      graph_variables = get_variables(graph)

      new_variables = Enum.map(graph_variables, fn v ->
        Variable.copy(v) |> tap(fn c -> Variable.remove(c, 3) end) end)

      {updated_graph, _bound_propagators} = ConstraintGraph.update(graph, new_variables)
      ## The domains fo variables in the graph should be updated with domains of new variables
      assert Enum.all?(get_variables(updated_graph),
        fn var ->
        Domain.to_list(var.domain) == MapSet.new([1,2])
      end)

      ## The propagators should be bound to new variables
      assert_propagator_domains(updated_graph, 1..2)
    end

    defp build_graph(constraint_impl, n) do
      domain = 1..n
      variables = Enum.map(1..n, fn _i -> Variable.new(domain) end)
      constraint = Constraint.new(constraint_impl, variables)
      propagators = Constraint.constraint_to_propagators(constraint)
      ConstraintGraph.create(propagators)
    end

    defp get_variable_ids(graph) do
      Graph.vertices(graph)
      |> Enum.flat_map(fn
        {:variable, v} -> [v]
        _ -> []
      end)
    end

    defp get_variables(graph) do
      graph
      |> get_variable_ids()
      |> Enum.map(fn var_id -> ConstraintGraph.get_variable(graph, var_id) end)
    end

    defp assert_propagator_domains(graph, domain) do
      propagators = Enum.flat_map(Graph.vertices(graph),
      fn {:propagator, p_id} ->
        [
          ConstraintGraph.get_propagator(graph, p_id)
          |> Propagator.bind(graph, :domain)
        ]
        _ -> []
      end)

      assert length(propagators) == 3
      assert Enum.all?(propagators,
        fn p ->

          Enum.all?(p.args, fn arg ->
            is_integer(arg) || Interface.domain(arg) |> Domain.to_list()
            == MapSet.new(domain)  end)
    end)
  end
  end
end
