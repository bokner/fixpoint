defmodule CPSolver.Propagator.Thread do
  use ExUnit.Case

  import ExUnit.CaptureLog

  describe "Propagator thread" do
    alias CPSolver.Propagator
    alias CPSolver.Store.Registry, as: Store
    alias CPSolver.IntVariable
    alias CPSolver.Variable
    alias CPSolver.Propagator.NotEqual

    test "create propagator thread" do
      space = :top_space
      x = 1..1
      y = -5..5
      variables = Enum.map([x, y], fn d -> IntVariable.new(d) end)

      {:ok, [x_var, y_var] = bound_vars} = Store.create(space, variables)

      {:ok, propagator_thread} = Propagator.create_thread(space, {NotEqual, bound_vars})
      ## Propagator thread subscribes to its variables
      assert Enum.all?(bound_vars, fn var -> propagator_thread in Variable.subscribers(var) end)
      ## ...filters its variables upon start
      refute Store.get(space, y_var, :contains?, [1])
      ## ...receives variable update notifications
      assert capture_log([level: :debug], fn ->
               Store.update(space, y_var, :removeBelow, [0])
               Process.sleep(1)
             end) =~ "Propagator: :min_change for #{inspect(y_var.id)}"

      ## ...triggers filtering on receiving update notifications
      assert capture_log([level: :debug], fn ->
               Store.update(space, y_var, :fix, [1])
               Process.sleep(1)
             end) =~ "Failure for variable #{inspect(y_var.id)}"
    end

    test "entailment" do
      space = :top_space
      x = 0..2
      y = -5..5
      variables = Enum.map([x, y], fn d -> IntVariable.new(d) end)

      {:ok, [x_var, y_var] = bound_vars} = Store.create(space, variables)

      {:ok, propagator_thread} = Propagator.create_thread(space, {NotEqual, bound_vars})

      refute capture_log([level: :debug], fn ->
               Store.update(space, x_var, :fix, [1])
               Process.sleep(50)
             end) =~ "Propagator entailed"

      entailment_log =
        capture_log([level: :debug], fn ->
          Store.update(space, y_var, :fix, [2])
          Process.sleep(50)
        end)

      ## TODO: check if entailment happens once!
      assert entailment_log =~ "Propagator is entailed"
    end
  end
end
