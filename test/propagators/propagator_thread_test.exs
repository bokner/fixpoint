defmodule CPSolverTest.Propagator.Thread do
  use ExUnit.Case

  import ExUnit.CaptureLog
  import CPSolver.Test.Helpers

  describe "Propagator thread" do
    alias CPSolver.Propagator.Thread, as: PropagatorThread
    alias CPSolver.ConstraintStore
    alias CPSolver.IntVariable
    alias CPSolver.Variable
    alias CPSolver.Propagator.NotEqual

    @domain_changes CPSolver.Common.domain_changes()

    setup do
      Logger.configure(level: :debug)
      on_exit(fn -> Logger.configure(level: :error) end)
    end

    @entailment_str "Propagator is entailed"

    test "create propagator thread" do
      x = 1..1
      y = -5..5
      variables = Enum.map([x, y], fn d -> IntVariable.new(d) end)

      {:ok, [x_var, y_var] = bound_vars, store, _store_impl} =
        ConstraintStore.create_store(variables)

      {:ok, _propagator_thread} =
        PropagatorThread.create_thread(self(), {NotEqual, bound_vars},
          propagate_on: @domain_changes,
          store: store
        )

      ## ...filters its variables upon start (happens in handle_continue, so needs a small timeout here)
      Process.sleep(5)
      refute Variable.contains?(y_var, 1)
      ## ...receives variable update notifications
      assert capture_log([level: :debug], fn ->
               Variable.removeBelow(y_var, 0)
               Process.sleep(10)
             end) =~ "Propagation triggered"

      ## ...triggers filtering on receiving update notifications
      assert capture_log([level: :debug], fn ->
               Variable.remove(x_var, 1)
               Process.sleep(10)
             end) =~ "Failure for variable #{inspect(x_var.id)}"
    end

    test "entailment with initially unfixed variables" do
      x = 0..2
      y = -5..5
      variables = Enum.map([x, y], fn d -> IntVariable.new(d) end)

      {:ok, [x_var, y_var] = bound_vars, store, store_impl} =
        ConstraintStore.create_store(variables)

      {:ok, propagator_thread} =
        PropagatorThread.create_thread(self(), {NotEqual, bound_vars}, store: store)

      Process.sleep(10)

      refute capture_log([level: :debug], fn ->
               store_impl.update(store, x_var, :fix, [1])
               Process.sleep(10)
             end) =~ @entailment_str

      entailment_log =
        capture_log([level: :debug], fn ->
          store_impl.update(store, y_var, :fix, [2])
          Process.sleep(10)
        end)

      ## An entailment happens exactly once
      assert number_of_occurences(entailment_log, @entailment_str) == 1
      ## Propagator thread discards itself on entailment
      Process.sleep(10)
      refute Process.alive?(propagator_thread)
    end

    test "entailment with initially fixed variables" do
      x = 0..0
      y = 1..1

      variables = Enum.map([x, y], fn d -> IntVariable.new(d) end)

      {:ok, bound_vars, store, _store_impl} = ConstraintStore.create_store(variables)

      assert capture_log([level: :debug], fn ->
               {:ok, propagator_thread} =
                 PropagatorThread.create_thread(self(), {NotEqual, bound_vars}, store: store)

               ## Propagator thread discards itself on entailment
               Process.sleep(10)
               refute Process.alive?(propagator_thread)
             end) =~ @entailment_str
    end

    test "Starting/stopping propagator subscribes it to/unsubscribes it from  its variables" do
      x = 0..2
      y = -5..5
      variables = Enum.map([x, y], fn d -> IntVariable.new(d) end)

      {:ok, vars, store, _store_impl} = ConstraintStore.create_store(variables)

      {:ok, propagator_thread} =
        PropagatorThread.create_thread(self(), {NotEqual, vars}, store: store)

      PropagatorThread.dispose(propagator_thread)
      Process.sleep(10)
      refute Process.alive?(propagator_thread)
    end

    test "stability" do
      x = 0..5
      y = 1..3
      variables = Enum.map([x, y], fn d -> IntVariable.new(d) end)

      {:ok, [x_var, y_var] = vars, store, store_impl} = ConstraintStore.create_store(variables)

      ## Detects stability on a startup
      assert capture_log([level: :debug], fn ->
               {:ok, _propagator_thread} =
                 PropagatorThread.create_thread(self(), {NotEqual, vars}, store: store)

               Process.sleep(10)
             end) =~ "is stable"

      ## Filtering that leaves unfixed variable(s) (x_var in this case) should
      ## (eventually) put propagator into 'stable' state
      assert capture_log([level: :debug], fn ->
               store_impl.update(store, y_var, :fix, [1])
               Process.sleep(10)
             end) =~ "is stable"

      ## Fixing all variables (i.e., entailment)
      ## does not result in stability.
      refute capture_log([level: :debug], fn ->
               store_impl.update(store, x_var, :fix, [0])
               Process.sleep(10)
             end) =~ "is stable"
    end

    test "propagator failure" do
      x = 1..1
      y = 1..2
      z = 2..2
      variables = Enum.map([x, y, z], fn d -> IntVariable.new(d) end)

      {:ok, [x_var, y_var, z_var] = _vars, store, _store_impl} =
        ConstraintStore.create_store(variables)

      {:ok, _threadXY} =
        PropagatorThread.create_thread(self(), {NotEqual, [x_var, y_var]},
          id: "X != Y",
          store: store
        )

      {:ok, _threadYZ} =
        PropagatorThread.create_thread(self(), {NotEqual, [y_var, z_var]},
          id: "Y != Z",
          store: store
        )

      Process.sleep(5)
      assert 1 == Variable.min(x_var)

      ## Non-deterministic failure - fails on either 'y' or 'z', depending on which propagator fixes first.
      assert :fail == Variable.min(z_var) || :fail == Variable.min(y_var)
    end
  end
end
