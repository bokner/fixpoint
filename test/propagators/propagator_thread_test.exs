defmodule CPSolverTest.Propagator.Thread do
  use ExUnit.Case

  describe "Propagator thread" do
    alias CPSolver.Propagator.Thread, as: PropagatorThread
    alias CPSolver.ConstraintStore
    alias CPSolver.IntVariable
    alias CPSolver.Variable
    alias CPSolver.Propagator.NotEqual

    test "create propagator thread" do
      x = 1..1
      y = -5..5
      z = 0..0
      variables = Enum.map([x, y, z], fn d -> IntVariable.new(d) end)

      {:ok, [x_var, y_var, z_var] = _bound_vars, store} =
        ConstraintStore.create_store(variables, space: nil)

      {:ok, _propagator_thread} =
        PropagatorThread.create_thread(self(), NotEqual.new(x_var, y_var), store: store)

      ## ...filters its variables upon start (happens in handle_continue, so needs a small timeout here)
      Process.sleep(10)
      refute Variable.contains?(y_var, 1)

      ## Note: we start propagator thread, but don't filter on a startup
      {:ok, _propagator_thread} =
        PropagatorThread.create_thread(self(), NotEqual.new(y_var, z_var),
          filter_on_startup: false,
          store: store
        )

      ## Fix 'y' to 0 so the propagator triggers a failure, as 'z' is also fixed to 0
      assert :fixed = Variable.fix(y_var, 0)
      Process.sleep(10)
      # assert :fail == Variable.domain(z_var)
    end

    test "entailment with initially unfixed variables" do
      x = 0..2
      y = -5..5
      variables = Enum.map([x, y], fn d -> IntVariable.new(d) end)

      ## space = nil results in Store notifying propagators directly
      {:ok, [x_var, y_var] = bound_vars, store} =
        ConstraintStore.create_store(variables, space: nil)

      {:ok, propagator_thread} =
        PropagatorThread.create_thread(self(), NotEqual.new(bound_vars),
          store: store,
          subscribe_to_events: true
        )

      ConstraintStore.update(store, x_var, :fix, [1])
      Process.sleep(10)
      refute_received {:entailed, _}

      ConstraintStore.update(store, y_var, :fix, [2])
      Process.sleep(10)

      assert_received {:entailed, _}
      ## Propagator thread discards itself on entailment
      Process.sleep(10)
      refute Process.alive?(propagator_thread)
    end

    test "entailment with initially fixed variables" do
      x = 0..0
      y = 1..1

      variables = Enum.map([x, y], fn d -> IntVariable.new(d) end)

      {:ok, bound_vars, store} = ConstraintStore.create_store(variables)

      {:ok, propagator_thread} =
        PropagatorThread.create_thread(self(), NotEqual.new(bound_vars), store: store)

      ## Propagator thread discards itself on entailment
      Process.sleep(10)
      assert_received {:entailed, _}
      refute Process.alive?(propagator_thread)
    end

    test "Starting/stopping propagator subscribes it to/unsubscribes it from  its variables" do
      x = 0..2
      y = -5..5
      variables = Enum.map([x, y], fn d -> IntVariable.new(d) end)

      {:ok, vars, store} = ConstraintStore.create_store(variables)

      {:ok, propagator_thread} =
        PropagatorThread.create_thread(self(), NotEqual.new(vars), store: store)

      PropagatorThread.dispose(propagator_thread)
      Process.sleep(10)
      refute Process.alive?(propagator_thread)
    end

    test "stability" do
      x = 0..5
      y = 1..3
      variables = Enum.map([x, y], fn d -> IntVariable.new(d) end)

      {:ok, [x_var, y_var] = vars, store} = ConstraintStore.create_store(variables, space: nil)

      ## Detects stability on a startup
      {:ok, propagator_thread} =
        PropagatorThread.create_thread(self(), NotEqual.new(vars),
          store: store,
          subscribe_to_events: true
        )

      Process.sleep(10)

      assert_received {:stable, _}
      ## Filtering that leaves unfixed variable(s) (x_var in this case) should
      ## (eventually) put propagator into 'stable' state
      ConstraintStore.update(store, y_var, :fix, [1])
      Process.sleep(10)

      assert_received {:stable, _}

      ## The propagator is stable, and so has to live..
      assert Process.alive?(propagator_thread)

      ## Fixing all variables (i.e., entailment)
      ## does not result in stability.
      ConstraintStore.update(store, x_var, :fix, [0])
      Process.sleep(10)

      assert_received {:entailed, _}
      ## The propagator has gone (entailnment had stopped it)
      refute Process.alive?(propagator_thread)
    end

    test "propagator failure" do
      x = 1..1
      y = 1..2
      z = 2..2
      variables = Enum.map([x, y, z], fn d -> IntVariable.new(d) end)

      {:ok, [x_var, y_var, z_var] = _vars, store} =
        ConstraintStore.create_store(variables, space: nil)

      {:ok, _threadXY} =
        PropagatorThread.create_thread(self(), NotEqual.new(x_var, y_var),
          id: "X != Y",
          store: store
        )

      {:ok, _threadYZ} =
        PropagatorThread.create_thread(self(), NotEqual.new(y_var, z_var),
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
