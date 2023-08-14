defmodule CPSolver.Propagator.Thread do
  use ExUnit.Case

  import ExUnit.CaptureLog

  describe "Propagator thread" do
    alias CPSolver.Propagator
    alias CPSolver.Store.Registry, as: Store
    alias CPSolver.IntVariable
    alias CPSolver.Variable
    alias CPSolver.Propagator.NotEqual

    @entailment_str "Propagator is entailed"

    test "create propagator thread" do
      space = :top_space
      x = 1..1
      y = -5..5
      variables = Enum.map([x, y], fn d -> IntVariable.new(d) end)

      {:ok, [_x_var, y_var] = bound_vars} = Store.create(space, variables)

      {:ok, propagator_thread} = Propagator.create_thread(space, {NotEqual, bound_vars})
      ## Propagator thread subscribes to its variables
      assert Enum.all?(bound_vars, fn var -> propagator_thread in Variable.subscribers(var) end)
      ## ...filters its variables upon start
      refute Store.get(space, y_var, :contains?, [1])
      ## ...receives variable update notifications
      assert capture_log([level: :debug], fn ->
               Store.update(space, y_var, :removeBelow, [0])
               Process.sleep(10)
             end) =~ "Propagator: :min_change for #{inspect(y_var.id)}"

      ## ...triggers filtering on receiving update notifications
      assert capture_log([level: :debug], fn ->
               Store.update(space, y_var, :fix, [1])
               Process.sleep(10)
             end) =~ "Failure for variable #{inspect(y_var.id)}"
    end

    test "entailment with initially unfixed variables" do
      space = :top_space
      x = 0..2
      y = -5..5
      variables = Enum.map([x, y], fn d -> IntVariable.new(d) end)

      {:ok, [x_var, y_var] = bound_vars} = Store.create(space, variables)

      {:ok, propagator_thread} = Propagator.create_thread(space, {NotEqual, bound_vars})

      refute capture_log([level: :debug], fn ->
               Store.update(space, x_var, :fix, [1])
               Process.sleep(10)
             end) =~ @entailment_str

      entailment_log =
        capture_log([level: :debug], fn ->
          Store.update(space, y_var, :fix, [2])
          Process.sleep(10)
        end)

      ## An entailment happens exactly once
      assert entailment_log =~ @entailment_str
      refute String.replace(entailment_log, @entailment_str, "") =~ @entailment_str
      ## Propagator thread discards itself on entailment
      Process.sleep(10)
      refute Process.alive?(propagator_thread)
    end

    test "entailment with initially fixed variables" do
      space = :top_space
      x = 0..0
      y = 1..1

      variables = Enum.map([x, y], fn d -> IntVariable.new(d) end)

      {:ok, bound_vars} = Store.create(space, variables)

      assert capture_log([level: :debug], fn ->
               {:ok, propagator_thread} = Propagator.create_thread(space, {NotEqual, bound_vars})
               ## Propagator thread discards itself on entailment
               Process.sleep(10)
               refute Process.alive?(propagator_thread)
             end) =~ @entailment_str
    end

    test "Starting/stopping propagator subscribes it to/unsubscribes it from  its variables" do
      space = :top_space
      x = 0..2
      y = -5..5
      variables = Enum.map([x, y], fn d -> IntVariable.new(d) end)

      {:ok, vars} = Store.create(space, variables)

      {:ok, propagator_thread} = Propagator.create_thread(space, {NotEqual, vars})

      assert Enum.all?(vars, fn v -> propagator_thread in :ebus.subscribers(Variable.topic(v)) end)

      GenServer.stop(propagator_thread)
      Process.sleep(10)
      refute Process.alive?(propagator_thread)

      refute Enum.any?(vars, fn v -> propagator_thread in :ebus.subscribers(Variable.topic(v)) end)
    end
  end
end
