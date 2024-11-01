defmodule CPSolverTest.Search.AFC do
  use ExUnit.Case

  alias CPSolver.Search.VariableSelector.AFC, as: AFC
  alias CPSolver.Space
  import CPSolver.Test.Helpers

  describe "AFC search strategy" do
    alias CPSolver.Shared

    test "initialization from top space" do
      space = build_space()
      shared = Space.get_shared(space)
      decay = :rand.uniform()
      AFC.initialize(space, decay)

      assert decay == AFC.get_decay(shared)

      afc_table_ref = AFC.get_afc_table(shared)
      propagator_refs = Enum.map(space.propagators, fn p -> p.id end)

      assert Enum.all?(
               :ets.tab2list(afc_table_ref),
               fn {p_ref, {1, 0}} -> p_ref in propagator_refs end
             )
    end

    test "get AFC record for propagator" do
      space = build_space()
      AFC.initialize(space, :rand.uniform())
      propagator_refs = Enum.map(space.propagators, fn p -> p.id end)

      shared = Space.get_shared(space)

      assert Enum.all?(propagator_refs, fn p_id ->
               {1, 0} = AFC.get_afc_record(p_id, shared)
             end)
    end

    test "update propagator AFC" do
      space = build_space()
      shared = Space.get_shared(space)
      decay = :rand.uniform()
      AFC.initialize(space, decay)
      [p1, p2, p3 | _rest] = Enum.map(space.propagators, fn p -> p.id end)

      ## Simulate propagator failure for 'p1' propagator
      Shared.add_failure(shared, {:fail, p1})
      {p1_afc, 1} = AFC.get_afc_record(p1, shared)
      assert p1_afc == 2

      ## Manually decay p2
      AFC.update_afc(p2, shared, false)
      ## AFC record advances to decayed value and the last global failure count
      assert {decay, 1} == AFC.get_afc_record(p2, shared)
      ## Simulate propagator failure for 'p2' propagator
      Shared.add_failure(shared, {:fail, p2})

      ## Trigger update for 'p2'
      ## AFC record is incremented by 1, the last global failure count is updated
      assert {decay + 1, 2} == AFC.get_afc_record(p2, shared)
      ## Compute AFC for 'p1' again, it should be decayed once.
      assert {p1_afc * decay, 2} == AFC.propagator_afc(p1, shared)
      ## Compute AFC for 'p3'. It should be decayed twice from initial value of 1.
      assert {decay * decay, 2} == AFC.propagator_afc(p3, shared)
    end

    test "Caliculate variable AFC" do
      space = build_space()
      shared = Space.get_shared(space)

      decay = :rand.uniform()
      AFC.initialize(space, decay)
      variables = space.variables

      ## The propagators in the space setup are:
      ## X != Y, X != Z, Y != Z
      ##
      ## That is, each variable participates in 2 propagators.
      ## 1. The initial AFC for every variable should be equal to 2.
      assert Enum.all?(variables, fn var -> 2 == AFC.variable_afc(var, shared) end)

      [p1, _p2, _p3] = space.propagators
      ## 2. Fail the propagator x != y
      ## This should increment AFCs for variables x and y and decay AFC for variable z
      assert Enum.map(p1.args, fn arg -> arg.name end) == ["x", "y"]

      Shared.add_failure(shared, {:fail, p1.id})
      [var1, var2, var3] = space.variables
      assert var1.name == "x" && var2.name == "y" && var3.name == "z"
      ## Variables `x` and `y` participate in 1 failed (x != y) and 1 non-failed propagator.
      ## Hence the AFC for both of these variables is (2 + decay)
      assert 2 + decay == AFC.variable_afc(var1, shared)
      assert 2 + decay == AFC.variable_afc(var2, shared)
      ## Both propagators variable `z` have not failed, both of them decayed.
      ## So AFC for `z` is (2 * decay)
      assert 2 * decay == AFC.variable_afc(var3, shared)
      #assert Enum.all?(variables, fn var -> 2 == AFC.variable_afc(var, shared) end)

    end

    defp build_space() do
      shared = Shared.init_shared_data(space_threads: 4)

      space_setup(0..5, 0..5, 0..5)
      |> Map.put(:opts, solver_data: shared)
      |> tap(fn space ->
        Space.put_shared(space, :initial_constraint_graph, space.constraint_graph)
      end)
    end
  end
end
