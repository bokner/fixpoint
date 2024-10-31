defmodule CPSolverTest.Search.AFC do
  use ExUnit.Case

  alias CPSolver.Search.VariableSelector.AFC, as: AFC
  alias CPSolver.Space
  import CPSolver.Test.Helpers

  describe "AFC search strategy" do
    alias CPSolver.Shared

    test "initialization from top space" do
      space = build_space()
      AFC.initialize(space)
      afc_table_ref = AFC.get_afc_table(Space.get_shared(space))
      propagator_refs = Enum.map(space.propagators, fn p -> p.id end)

      assert Enum.all?(
               :ets.tab2list(afc_table_ref),
               fn {p_ref, {1, 0}} -> p_ref in propagator_refs end
             )
    end

    test "get AFC record for propagator" do
      space = build_space()
      AFC.initialize(space)
      propagator_refs = Enum.map(space.propagators, fn p -> p.id end)

      shared = Space.get_shared(space)
      assert Enum.all?(propagator_refs, fn p_id ->
               {1, 0} = AFC.get_afc_record(shared, p_id)
             end)
    end

    defp build_space() do
      shared = Shared.init_shared_data(space_threads: 4)
      space_setup(0..5, 0..5, 0..5) |> Map.put(:opts, solver_data: shared)
    end
  end
end
